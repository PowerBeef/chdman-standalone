import Foundation

/// Best-effort identification of a CD image by reading its headers —
/// no online lookups, no big database. Pulls:
///
///   1. ISO 9660 Primary Volume Descriptor (sector 16) → volume label.
///   2. Platform-specific signatures at the start of the data track:
///      - Sega Saturn: "SEGA SEGASATURN" header with embedded title + product number
///      - Sega Dreamcast: "SEGA SEGAKATANA" GD-ROM IP.BIN header
///   3. PlayStation game ID (SLUS-00485 etc.) by scanning the first
///      ~1 MB of the data track for the disc boot code.
///
/// Sector layout is auto-detected: we find "CD001" in the leading
/// chunk of the file and back-reason from there, so MODE1/2048,
/// MODE1/2352, and MODE2/2352 all work without the caller telling us.
enum DiscInspector {

    struct Identity: Equatable, Sendable {
        var volumeLabel: String?
        var platform: Platform?
        var gameID: String?
        var headerTitle: String?

        var hasAnything: Bool {
            volumeLabel != nil || platform != nil || gameID != nil || headerTitle != nil
        }

        /// Best human label — prefer header title, then volume label, then nothing.
        /// Suppresses the volume label when it's just the game ID in disc-form
        /// (PS1 discs use the boot code "SLUS_004.85" as the label, which would
        /// duplicate the parsed game ID "SLUS-00485").
        var bestTitle: String? {
            if let t = headerTitle, !t.isEmpty { return t }
            if let v = volumeLabel, !v.isEmpty {
                if let g = gameID {
                    let normalized = v
                        .replacingOccurrences(of: "_", with: "-")
                        .replacingOccurrences(of: ".", with: "")
                    if normalized == g { return nil }
                }
                return v
            }
            return nil
        }
    }

    enum Platform: String, Equatable, Sendable {
        case ps1 = "PS1"
        case saturn = "Saturn"
        case dreamcast = "Dreamcast"
        case cdrom = "CD-ROM"
    }

    /// Inspect a binary track file (.bin / .iso / single-track image).
    /// Returns nil if the file can't be opened. Returns an empty
    /// Identity if nothing identifiable was found.
    static func inspect(dataFileURL: URL) -> Identity? {
        guard let chunk = readPrefix(of: dataFileURL, bytes: 1_048_576) else { return nil }
        var identity = Identity()

        var systemID: String?
        if let layout = SectorLayout.detect(in: chunk) {
            identity.volumeLabel = parseVolumeLabel(chunk: chunk, layout: layout)
            systemID = parseSystemID(chunk: chunk, layout: layout)
        }

        if let saturn = detectSaturn(chunk: chunk) {
            identity.platform = .saturn
            identity.gameID = saturn.productNumber
            identity.headerTitle = saturn.title
        } else if let dc = detectDreamcast(chunk: chunk) {
            identity.platform = .dreamcast
            identity.gameID = dc.productNumber
            identity.headerTitle = dc.title
        } else if let ps1 = detectPS1(chunk: chunk) {
            identity.platform = .ps1
            identity.gameID = ps1
        } else if let sid = systemID, sid.uppercased().hasPrefix("PLAYSTATION") {
            // Boot-code regex missed (or the disc just lacks one in the
            // first MB), but the PVD's system identifier is "PLAYSTATION".
            // That's an authoritative platform signal.
            identity.platform = .ps1
        } else if identity.volumeLabel != nil {
            identity.platform = .cdrom
        }

        return identity.hasAnything ? identity : Identity()
    }

    // MARK: - File I/O

    private static func readPrefix(of url: URL, bytes: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: bytes)
    }

    // MARK: - ISO 9660

    /// Where the ISO 9660 user data starts within each sector for
    /// the layout containing the PVD signature we found.
    private struct SectorLayout {
        let sectorSize: Int
        let userDataOffset: Int   // where 2048 bytes of user data begin within a sector

        static func detect(in chunk: Data) -> SectorLayout? {
            // PVD lives at sector 16. Try the three common layouts; the
            // first one whose sector-16 user area starts with `\x01CD001`
            // wins. We look at byte +1 because the first byte is type
            // code (1 for PVD) and "CD001" is the standard identifier.
            let candidates: [SectorLayout] = [
                .init(sectorSize: 2048, userDataOffset: 0),
                .init(sectorSize: 2352, userDataOffset: 16),
                .init(sectorSize: 2352, userDataOffset: 24),
                .init(sectorSize: 2336, userDataOffset: 8),
            ]
            for layout in candidates {
                let pvdAbs = layout.sectorSize * 16 + layout.userDataOffset
                guard pvdAbs + 6 <= chunk.count else { continue }
                let typeCode = chunk[pvdAbs]
                let id = chunk.subdata(in: (pvdAbs + 1)..<(pvdAbs + 6))
                if typeCode == 1, id == Data("CD001".utf8) {
                    return layout
                }
            }
            return nil
        }
    }

    private static func parseVolumeLabel(chunk: Data, layout: SectorLayout) -> String? {
        // Volume Identifier is 32 bytes at offset 40 within the PVD.
        let pvdAbs = layout.sectorSize * 16 + layout.userDataOffset
        return readPVDField(chunk: chunk, start: pvdAbs + 40, length: 32)
    }

    private static func parseSystemID(chunk: Data, layout: SectorLayout) -> String? {
        // System Identifier is 32 bytes at offset 8 within the PVD.
        // For PSX discs this is "PLAYSTATION" — an authoritative platform tag.
        let pvdAbs = layout.sectorSize * 16 + layout.userDataOffset
        return readPVDField(chunk: chunk, start: pvdAbs + 8, length: 32)
    }

    /// Decode a fixed-width PVD string field. Latin-1 always succeeds
    /// for any byte sequence; ASCII would return nil if the chunk
    /// contained any byte ≥ 0x80, which can happen with corrupted or
    /// non-conforming images. Trims trailing space + NUL padding.
    private static func readPVDField(chunk: Data, start: Int, length: Int) -> String? {
        let end = start + length
        guard end <= chunk.count else { return nil }
        let raw = chunk.subdata(in: start..<end)
        guard let s = String(data: raw, encoding: .isoLatin1) else { return nil }
        let trimmed = s.trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Saturn

    /// Saturn IP.BIN layout (first sector of track 1, no sync/header):
    ///   0x000  16  "SEGA SEGASATURN "
    ///   0x010  16  Maker ID
    ///   0x020  10  Product number     (e.g. "GS-9101   ")
    ///   0x02A   6  Version
    ///   0x030   8  Release date (YYYYMMDD)
    ///   0x038   3  Device info
    ///   0x03B   1  reserved
    ///   0x040  10  Compatible area symbols
    ///   0x050  16  Compatible peripherals
    ///   0x060 112  Title (Shift_JIS / ASCII)
    private static func detectSaturn(chunk: Data) -> (productNumber: String, title: String)? {
        let header = "SEGA SEGASATURN "
        guard let baseOffset = findHeaderOffset(in: chunk, header: header) else { return nil }
        guard baseOffset + 0x100 <= chunk.count else { return nil }
        let productNumber = readASCII(chunk: chunk,
                                      range: (baseOffset + 0x20)..<(baseOffset + 0x2A))
        let title = readASCII(chunk: chunk,
                              range: (baseOffset + 0x60)..<(baseOffset + 0xD0))
        return (productNumber, title)
    }

    // MARK: - Dreamcast

    /// Dreamcast IP.BIN layout (similar idea):
    ///   0x000  16  "SEGA SEGAKATANA "
    ///   0x010  16  "SEGA ENTERPRISES"
    ///   0x040  10  Product number
    ///   0x080 128  Title
    private static func detectDreamcast(chunk: Data) -> (productNumber: String, title: String)? {
        let header = "SEGA SEGAKATANA "
        guard let baseOffset = findHeaderOffset(in: chunk, header: header) else { return nil }
        guard baseOffset + 0x100 <= chunk.count else { return nil }
        let productNumber = readASCII(chunk: chunk,
                                      range: (baseOffset + 0x40)..<(baseOffset + 0x4A))
        let title = readASCII(chunk: chunk,
                              range: (baseOffset + 0x80)..<(baseOffset + 0x100))
        return (productNumber, title)
    }

    // MARK: - PlayStation

    /// PS1 boot codes look like SLUS_004.85, SLES_011.62, SCES_001.05,
    /// SLPS_021.76, SCPS_..., SLPM_..., etc. The on-disc form has an
    /// underscore and a dot (filesystem-safe). The user-facing form is
    /// SLUS-00485. We extract them in the user-facing form.
    private static let ps1Pattern: NSRegularExpression = {
        // 4-char prefix from the known set, then _NNN.NN
        let prefix = "(?:SLUS|SLES|SLPS|SLPM|SCUS|SCES|SCPS|SCPM|SCAJ|SLED|PAPX|PCPX|PBPX)"
        return try! NSRegularExpression(pattern: "\(prefix)_\\d{3}\\.\\d{2}")
    }()

    private static func detectPS1(chunk: Data) -> String? {
        // ASCII decoding fails on any chunk containing a byte ≥ 0x80,
        // which is virtually every real PS1 disc dump. Latin-1 maps
        // every byte 1:1 and never returns nil, and the regex only
        // matches ASCII characters anyway, so this is safe.
        guard let text = String(data: chunk, encoding: .isoLatin1) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = ps1Pattern.firstMatch(in: text, range: range),
              let r = Range(m.range, in: text) else { return nil }
        let raw = String(text[r])              // e.g. "SLUS_004.85"
        // Convert to user-facing "SLUS-00485"
        return raw
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: ".", with: "")
    }

    // MARK: - Helpers

    /// Look for `header` at sector 0 of the data track in any of the
    /// common sector layouts. Returns the byte offset of `header[0]`.
    private static func findHeaderOffset(in chunk: Data, header: String) -> Int? {
        let needle = Data(header.utf8)
        let candidates: [Int] = [0, 16, 24, 8] // MODE1/2048 raw, MODE1/2352, MODE2/2352, MODE2/2336
        for offset in candidates {
            guard offset + needle.count <= chunk.count else { continue }
            let slice = chunk.subdata(in: offset..<(offset + needle.count))
            if slice == needle { return offset }
        }
        return nil
    }

    private static func readASCII(chunk: Data, range: Range<Int>) -> String {
        guard range.lowerBound >= 0, range.upperBound <= chunk.count else { return "" }
        let slice = chunk.subdata(in: range)
        guard let raw = String(data: slice, encoding: .ascii) else { return "" }
        return raw
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
