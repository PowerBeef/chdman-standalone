import Foundation
import Observation

enum InputKind: String {
    case cdImage      // .cue / .gdi / .toc / .iso → createcd
    case chd          // .chd → extract / info / verify

    static func detect(url: URL) -> InputKind? {
        switch url.pathExtension.lowercased() {
        case "cue", "gdi", "toc", "iso": return .cdImage
        case "chd": return .chd
        default: return nil
        }
    }
}

enum Action: String, CaseIterable, Identifiable {
    case createCD
    case extractCD
    case info
    case verify

    var id: String { rawValue }

    var label: String {
        switch self {
        case .createCD:  return "Create CHD"
        case .extractCD: return "Extract"
        case .info:      return "Info"
        case .verify:    return "Verify"
        }
    }

    var systemImage: String {
        switch self {
        case .createCD:  return "arrow.down.to.line"
        case .extractCD: return "arrow.up.from.line"
        case .info:      return "info.circle"
        case .verify:    return "checkmark.shield"
        }
    }

    static func defaultActions(for kind: InputKind) -> [Action] {
        switch kind {
        case .cdImage: return [.createCD]
        case .chd:     return [.extractCD, .info, .verify]
        }
    }

    static func defaultAction(for kind: InputKind) -> Action {
        defaultActions(for: kind).first!
    }
}

enum ItemStatus: Equatable {
    case idle
    case running(progress: Double)   // 0…1
    case done(message: String?)      // optional info text (e.g. "verify passed")
    case failed(message: String)
    case cancelled
}

struct FileFingerprint: Equatable, Hashable, Sendable {
    let size: UInt64
    let crc32: UInt32

    static func file(at url: URL) -> FileFingerprint? {
        // Use resourceValues — it follows symlinks. FileManager.attributesOfItem
        // returns the symlink's own size on macOS, which gives bogus matches.
        let resolved = url.resolvingSymlinksInPath()
        let size = (try? resolved.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            .flatMap { UInt64(exactly: $0) } ?? 0
        guard let crc = CRC32.file(at: url) else { return nil }
        return FileFingerprint(size: size, crc32: crc)
    }
}

@Observable
final class FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let kind: InputKind
    var action: Action
    var status: ItemStatus = .idle
    var outputURL: URL?              // populated on success when it's a file
    var infoOutput: String?          // captured stdout for `info`
    var logOutput: String?           // captured chdman output for recovery/details
    var references: [DiscSheet.Reference] = []  // data files referenced by cue/gdi/toc, or ISO itself
    var identity: DiscInspector.Identity?       // detected disc/game identity
    var referenceFingerprints: [URL: FileFingerprint] = [:]   // per-reference size + CRC32
    var sheetFingerprint: FileFingerprint?      // CUE/GDI/TOC sheet size + CRC32 when applicable
    var redumpStatuses: [URL: RedumpDatabase.Status] = [:]   // per-reference Redump match
    var auditIssues: [DiscAuditIssue] = []      // warning-level disc integrity findings
    var redumpUnavailablePlatform: DiscInspector.Platform? = nil
    var redumpInProgress: Bool = false          // true while CRC32 hashing references

    init(url: URL, kind: InputKind) {
        self.url = url
        self.kind = kind
        self.action = Action.defaultAction(for: kind)
        self.references = Self.detectReferences(url: url, kind: kind)
        self.identity = Self.detectIdentity(url: url, kind: kind, references: references)
    }

    /// Aggregate Redump verdict across all references that have been hashed.
    /// Picks the platform/game pair that appears as a verified candidate across the
    /// MOST bins — necessary because shared audio tracks can match multiple
    /// games (regional re-releases reuse the same music). The intersection
    /// of "all bins matched, and one identity is in every bin's candidate
    /// set" is the strongest signal.
    var redumpAggregate: RedumpAggregate {
        guard !references.isEmpty else { return .notApplicable }
        let known = references.compactMap { redumpStatuses[$0.url] }
        if known.isEmpty {
            if let redumpUnavailablePlatform {
                return redumpInProgress ? .checking : .unavailable(platform: redumpUnavailablePlatform)
            }
            return redumpInProgress ? .checking : .notApplicable
        }

        let inferredIdentity = DiscAudit.inferredGameIdentity(redumpStatuses: redumpStatuses)
        var anyCorrupted = false
        var anyUnknown = false
        var perBinGames: [Set<DiscAudit.RedumpIdentity>] = []
        for s in known {
            switch s {
            case .verified(let candidates):
                perBinGames.append(Set(candidates.map {
                    DiscAudit.RedumpIdentity(platformKey: $0.platformKey, gameName: $0.gameName)
                }))
            case .wrongTrack(let platformKey, _, _, let gameName):
                perBinGames.append([
                    DiscAudit.RedumpIdentity(platformKey: platformKey, gameName: gameName)
                ])
            case .sizeMatchedButCRCMismatch(let platformKey, let gameName, _):
                if inferredIdentity == DiscAudit.RedumpIdentity(platformKey: platformKey, gameName: gameName) {
                    anyCorrupted = true
                } else {
                    anyUnknown = true
                }
            case .unknown:
                anyUnknown = true
            }
        }
        if let redumpUnavailablePlatform, inferredIdentity == nil {
            return redumpInProgress ? .checking : .unavailable(platform: redumpUnavailablePlatform)
        }
        if anyCorrupted { return .corrupted }

        let verifiedBinCount = perBinGames.count
        let allHashed = known.count == references.count

        if verifiedBinCount > 0, allHashed, !anyUnknown {
            // Try to find an identity that's a verified candidate in every bin.
            if let consensus = perBinGames.dropFirst().reduce(perBinGames.first, { acc, set in
                acc?.intersection(set)
            }), let pick = consensus.first, consensus.count == 1 {
                return .verified(identity: pick)
            }
        }

        // No single game identity spanned all bins — but if the bins do have
        // SOME verified candidate, we can still surface a best-guess.
        if verifiedBinCount > 0 {
            // Pick the most-common platform/game pair across bins.
            var counts: [DiscAudit.RedumpIdentity: Int] = [:]
            for set in perBinGames {
                for identity in set { counts[identity, default: 0] += 1 }
            }
            if let bestCount = counts.values.max() {
                let best = counts.filter { $0.value == bestCount }.map(\.key)
                if best.count == 1 {
                    return .partial(verifiedIdentities: best)
                }
            }
        }
        return .unknown
    }

    enum RedumpAggregate: Equatable {
        case notApplicable                      // no references / not on a supported platform
        case unavailable(platform: DiscInspector.Platform)      // known platform, no bundled DAT
        case checking                           // hashing in progress
        case verified(identity: DiscAudit.RedumpIdentity)      // all references match one Redump game
        case partial(verifiedIdentities: [DiscAudit.RedumpIdentity])   // some matched but not yet all
        case corrupted                          // at least one bin has wrong CRC for known size
        case unknown                            // hashed and nothing matched
    }

    var displayName: String { url.lastPathComponent }

    var typeChip: String {
        switch kind {
        case .cdImage: return url.pathExtension.uppercased()
        case .chd:     return "CHD"
        }
    }

    /// Aggregate file-on-disk size for this item, formatted (e.g. "521 MB").
    /// Sums hashed reference sizes when the audit has run; falls back to the
    /// resource size of each referenced file or the item URL itself for `.chd`
    /// and bare `.iso` inputs. Returns nil if nothing on disk could be read.
    var formattedTotalSize: String? {
        let urls: [URL]
        switch kind {
        case .cdImage:
            urls = references.isEmpty ? [url] : references.map(\.url)
        case .chd:
            urls = [url]
        }
        var total: UInt64 = 0
        var anyFound = false
        for u in urls {
            // Prefer hashed fingerprint size (already symlink-resolved); fall
            // back to the live filesystem size.
            if let fp = referenceFingerprints[u] {
                total &+= fp.size
                anyFound = true
                continue
            }
            let resolved = u.resolvingSymlinksInPath()
            if let fileSize = (try? resolved.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                .flatMap({ UInt64(exactly: $0) }) {
                total &+= fileSize
                anyFound = true
            }
        }
        guard anyFound, total > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(clamping: total))
    }

    /// CRC32 of the item's primary data track, formatted as `abcd 1234` for
    /// readability. Available only after the Redump audit has hashed the
    /// referenced files. Returns nil for unaudited items and for `.chd`
    /// inputs (sealed archives — no per-track audit).
    var primaryCRC: String? {
        // Pick the first existing reference and return its hashed CRC, if any.
        for ref in references where ref.exists {
            if let fp = referenceFingerprints[ref.url] {
                return Self.formatCRC(fp.crc32)
            }
        }
        return nil
    }

    private static func formatCRC(_ value: UInt32) -> String {
        let hex = String(format: "%08x", value)
        let high = hex.prefix(4)
        let low = hex.suffix(4)
        return "\(high) \(low)"
    }

    /// True if every referenced data file is present on disk.
    /// Also true when there's nothing referenced (e.g. .iso, .chd).
    var allReferencesFound: Bool {
        references.allSatisfy(\.exists)
    }

    var missingReferenceCount: Int {
        references.lazy.filter { !$0.exists }.count
    }

    private static func detectReferences(url: URL, kind: InputKind) -> [DiscSheet.Reference] {
        guard kind == .cdImage else { return [] }
        switch url.pathExtension.lowercased() {
        case "cue", "gdi", "toc":
            return DiscSheet.references(in: url)
        case "iso":
            return [
                DiscSheet.Reference(
                    url: url.standardizedFileURL,
                    exists: FileManager.default.fileExists(atPath: url.path),
                    tracks: []
                )
            ]
        default:
            return []
        }
    }

    /// Find the BIN/IMG that contains the data track and run header
    /// inspection on it. For .iso the file IS the data track. For
    /// cue/gdi/toc, we use the first existing referenced file as a
    /// proxy for the data track (track 01 is virtually always data).
    /// CHDs are skipped — they'd require a temp extraction.
    private static func detectIdentity(
        url: URL,
        kind: InputKind,
        references: [DiscSheet.Reference]
    ) -> DiscInspector.Identity? {
        guard kind == .cdImage else { return nil }
        let dataFile: URL?
        switch url.pathExtension.lowercased() {
        case "iso":
            dataFile = url
        case "cue", "gdi", "toc":
            dataFile = references.first(where: \.exists)?.url
        default:
            dataFile = nil
        }
        guard let dataFile else { return nil }
        return DiscInspector.inspect(dataFileURL: dataFile)
    }
}
