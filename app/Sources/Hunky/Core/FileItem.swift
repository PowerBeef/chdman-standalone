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

@Observable
final class FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let kind: InputKind
    var action: Action
    var status: ItemStatus = .idle
    var outputURL: URL?              // populated on success when it's a file
    var infoOutput: String?          // captured stdout for `info`
    var references: [CueSheet.Reference] = []   // data files referenced by cue/gdi/toc
    var identity: DiscInspector.Identity?       // detected disc/game identity
    var redumpStatuses: [URL: RedumpDatabase.Status] = [:]   // per-reference Redump match
    var redumpInProgress: Bool = false          // true while CRC32 hashing references

    init(url: URL, kind: InputKind) {
        self.url = url
        self.kind = kind
        self.action = Action.defaultAction(for: kind)
        self.references = Self.detectReferences(url: url, kind: kind)
        self.identity = Self.detectIdentity(url: url, kind: kind, references: references)
    }

    /// Aggregate Redump verdict across all references that have been hashed.
    /// Picks the game name that appears as a verified candidate across the
    /// MOST bins — necessary because shared audio tracks can match multiple
    /// games (regional re-releases reuse the same music). The intersection
    /// of "all bins matched, and one game name is in every bin's candidate
    /// set" is the strongest signal.
    var redumpAggregate: RedumpAggregate {
        guard !references.isEmpty else { return .notApplicable }
        let known = references.compactMap { redumpStatuses[$0.url] }
        if known.isEmpty {
            return redumpInProgress ? .checking : .notApplicable
        }

        var anyCorrupted = false
        var anyUnknown = false
        var perBinGames: [Set<String>] = []
        for s in known {
            switch s {
            case .verified(let candidates):
                perBinGames.append(Set(candidates.map(\.gameName)))
            case .sizeMatchedButCRCMismatch:
                anyCorrupted = true
            case .unknown:
                anyUnknown = true
            }
        }
        if anyCorrupted { return .corrupted }

        let verifiedBinCount = perBinGames.count
        let allHashed = known.count == references.count

        if verifiedBinCount > 0, allHashed, !anyUnknown {
            // Try to find a game name that's a verified candidate in every bin.
            if let consensus = perBinGames.dropFirst().reduce(perBinGames.first, { acc, set in
                acc?.intersection(set)
            }), let pick = consensus.first, consensus.count >= 1 {
                return .verified(gameName: pick)
            }
        }

        // No single game name spanned all bins — but if the bins do have
        // SOME verified candidate, we can still surface a best-guess.
        if verifiedBinCount > 0 {
            // Pick the most-common game across bins.
            var counts: [String: Int] = [:]
            for set in perBinGames {
                for g in set { counts[g, default: 0] += 1 }
            }
            if let best = counts.max(by: { $0.value < $1.value }) {
                return .partial(verifiedGames: [best.key])
            }
        }
        return .unknown
    }

    enum RedumpAggregate: Equatable {
        case notApplicable                      // no references / not on a supported platform
        case checking                           // hashing in progress
        case verified(gameName: String)         // all references match one Redump game
        case partial(verifiedGames: [String])   // some matched but not yet all
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

    /// True if every referenced data file is present on disk.
    /// Also true when there's nothing referenced (e.g. .iso, .chd).
    var allReferencesFound: Bool {
        references.allSatisfy(\.exists)
    }

    var missingReferenceCount: Int {
        references.lazy.filter { !$0.exists }.count
    }

    private static func detectReferences(url: URL, kind: InputKind) -> [CueSheet.Reference] {
        guard kind == .cdImage else { return [] }
        switch url.pathExtension.lowercased() {
        case "cue", "gdi", "toc":
            return CueSheet.references(in: url)
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
        references: [CueSheet.Reference]
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
