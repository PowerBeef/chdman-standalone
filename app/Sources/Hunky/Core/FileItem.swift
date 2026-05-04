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

    init(url: URL, kind: InputKind) {
        self.url = url
        self.kind = kind
        self.action = Action.defaultAction(for: kind)
        self.references = Self.detectReferences(url: url, kind: kind)
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
}
