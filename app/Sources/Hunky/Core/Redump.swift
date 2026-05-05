import Foundation
import Compression

/// Loads bundled Redump DAT files and answers the question:
/// "does this file's CRC32 match a known-good entry, and which game is it from?"
///
/// DAT files are Logiqx XML — see http://www.logiqx.com/Dats/.
/// Format excerpt:
///
///   <game name="Twisted Metal 2 (USA)">
///     <rom name="Twisted Metal 2 (USA).cue" size="1374" crc="ea3d72cd" .../>
///     <rom name="Twisted Metal 2 (USA) (Track 01).bin" size="418187952" crc="c8f01e9d" .../>
///     ...
///   </game>
///
/// Hunky bundles each platform DAT gzipped (Resources/redump/<platform>.dat.gz).
/// On first lookup we lazily decompress + parse, then keep an in-memory
/// index keyed by CRC32 for O(1) match resolution.
@MainActor
final class RedumpDatabase {

    static let shared = RedumpDatabase()
    private init() {}

    struct Entry: Equatable {
        let gameName: String
        let romName: String
        let size: UInt64
        let crc32: UInt32
    }

    enum Status: Equatable {
        case verified(candidates: [Entry])     // All entries whose (CRC, size) match this file
        case sizeMatchedButCRCMismatch(gameName: String, romName: String)
        case unknown
    }

    private struct Index {
        // CRC32s aren't unique across the DAT — shared audio tracks often
        // appear in multiple games (regional releases, special editions).
        // Store every entry, let the caller disambiguate by cross-referencing
        // all the bins of a single cue.
        var byCRC: [UInt32: [Entry]] = [:]
        var sizesPresent: Set<UInt64> = []
    }

    /// Per-platform indexes, keyed by canonical platform key (e.g. "psx").
    /// Built lazily on first access, then cached forever.
    private var indexes: [String: Index] = [:]
    private var loadAttempted: Set<String> = []

    /// Look up a CRC32 + size combination across all loaded platforms.
    /// Returns ALL matching candidates (a CRC32 may appear in multiple
    /// games when audio tracks are reused across releases).
    func match(crc32: UInt32, size: UInt64) -> Status {
        ensureLoaded(platform: "psx")  // v1 ships PSX only

        var candidates: [Entry] = []
        for (_, idx) in indexes {
            if let entries = idx.byCRC[crc32] {
                for entry in entries where entry.size == size {
                    candidates.append(entry)
                }
            }
        }
        if !candidates.isEmpty {
            return .verified(candidates: candidates)
        }

        // Size matches a known entry but no CRC entry matched — looks corrupted.
        for (_, idx) in indexes where idx.sizesPresent.contains(size) {
            if let entry = anyEntry(matchingSize: size, across: idx) {
                return .sizeMatchedButCRCMismatch(
                    gameName: entry.gameName,
                    romName: entry.romName
                )
            }
        }
        return .unknown
    }

    private func anyEntry(matchingSize size: UInt64, across idx: Index) -> Entry? {
        // Pick any entry with this size — used only for the "looks corrupted"
        // hint. With ~50K entries and rare size collisions this is fine
        // even though it's a linear scan; called only on mismatch path.
        for entries in idx.byCRC.values {
            if let hit = entries.first(where: { $0.size == size }) {
                return hit
            }
        }
        return nil
    }

    // MARK: - Loading

    private func ensureLoaded(platform: String) {
        guard !loadAttempted.contains(platform) else { return }
        loadAttempted.insert(platform)

        let bundle = Bundle.main
        guard let url = bundle.url(forResource: platform,
                                   withExtension: "dat.gz",
                                   subdirectory: "redump") else {
            // Note: subdirectory may not work for files copied via
            // resource build phase — try plain lookup as fallback.
            if let urlFlat = bundle.url(forResource: "\(platform).dat", withExtension: "gz") {
                load(platform: platform, gzURL: urlFlat)
            }
            return
        }
        load(platform: platform, gzURL: url)
    }

    private func load(platform: String, gzURL: URL) {
        guard let xml = readGzipped(at: gzURL) else { return }
        var idx = Index()
        DATParser.parse(xml: xml) { entry in
            idx.byCRC[entry.crc32, default: []].append(entry)
            idx.sizesPresent.insert(entry.size)
        }
        indexes[platform] = idx
    }

    private func readGzipped(at url: URL) -> Data? {
        guard let compressed = try? Data(contentsOf: url) else { return nil }
        return gunzip(data: compressed)
    }

    /// Inflate a gzip blob using Apple's Compression framework.
    /// Compression's COMPRESSION_ZLIB doesn't handle gzip wrappers, so we
    /// strip the gzip header (10 bytes) + trailer (8 bytes) and feed the
    /// raw deflate stream to COMPRESSION_ZLIB.
    private func gunzip(data: Data) -> Data? {
        guard data.count > 18,
              data[0] == 0x1F, data[1] == 0x8B,    // gzip magic
              data[2] == 0x08                       // deflate
        else { return nil }

        var headerEnd = 10
        let flg = data[3]
        if (flg & 0x04) != 0 {                      // FEXTRA
            guard headerEnd + 2 <= data.count else { return nil }
            let xlen = Int(data[headerEnd]) | (Int(data[headerEnd + 1]) << 8)
            headerEnd += 2 + xlen
        }
        if (flg & 0x08) != 0 {                      // FNAME (zero-terminated)
            while headerEnd < data.count, data[headerEnd] != 0 { headerEnd += 1 }
            headerEnd += 1
        }
        if (flg & 0x10) != 0 {                      // FCOMMENT
            while headerEnd < data.count, data[headerEnd] != 0 { headerEnd += 1 }
            headerEnd += 1
        }
        if (flg & 0x02) != 0 {                      // FHCRC
            headerEnd += 2
        }
        guard headerEnd < data.count - 8 else { return nil }

        let payloadEnd = data.count - 8
        let payload = data.subdata(in: headerEnd..<payloadEnd)

        // Inflate via Compression. Use a generous output buffer; PSX DAT
        // is ~13 MB uncompressed, so 32 MB headroom is plenty.
        let outputCapacity = 32 * 1024 * 1024
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: outputCapacity)
        defer { dst.deallocate() }
        let written = payload.withUnsafeBytes { (rawSrc: UnsafeRawBufferPointer) -> Int in
            guard let srcBase = rawSrc.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                dst, outputCapacity,
                srcBase, payload.count,
                nil, COMPRESSION_ZLIB
            )
        }
        guard written > 0 else { return nil }
        return Data(bytes: dst, count: written)
    }
}

// MARK: - DAT XML parser

private final class DATParser: NSObject, XMLParserDelegate {
    typealias OnEntry = (RedumpDatabase.Entry) -> Void

    private var currentGameName: String?
    private let onEntry: OnEntry

    private init(onEntry: @escaping OnEntry) {
        self.onEntry = onEntry
    }

    static func parse(xml: Data, onEntry: @escaping OnEntry) {
        let p = XMLParser(data: xml)
        let delegate = DATParser(onEntry: onEntry)
        p.delegate = delegate
        p.parse()
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attrs: [String: String]) {
        switch elementName {
        case "game":
            currentGameName = attrs["name"]
        case "rom":
            guard let game = currentGameName,
                  let name = attrs["name"],
                  let sizeStr = attrs["size"],
                  let crcStr = attrs["crc"],
                  let size = UInt64(sizeStr),
                  let crc = UInt32(crcStr, radix: 16)
            else { return }
            onEntry(.init(gameName: game, romName: name, size: size, crc32: crc))
        default:
            break
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "game" {
            currentGameName = nil
        }
    }
}
