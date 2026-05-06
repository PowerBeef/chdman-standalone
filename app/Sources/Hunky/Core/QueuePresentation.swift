import Foundation

struct IntakeResult: Equatable {
    var added: Int = 0
    var duplicates: Int = 0
    var unsupported: Int = 0
    var emptyFolders: Int = 0

    var hasFeedback: Bool {
        added > 0 || duplicates > 0 || unsupported > 0 || emptyFolders > 0
    }

    var message: String? {
        guard hasFeedback else { return nil }
        var parts: [String] = []
        if added > 0 {
            parts.append("\(added) added")
        }
        if duplicates > 0 {
            parts.append("\(duplicates) duplicate\(duplicates == 1 ? "" : "s") skipped")
        }
        if unsupported > 0 {
            parts.append("\(unsupported) unsupported file\(unsupported == 1 ? "" : "s") skipped")
        }
        if emptyFolders > 0 {
            parts.append("\(emptyFolders) folder\(emptyFolders == 1 ? "" : "s") had no supported files")
        }
        return parts.joined(separator: ", ")
    }
}

enum RiskSeverity: Int, Comparable, Equatable {
    case notice = 0
    case caution = 1
    case critical = 2

    static func < (lhs: RiskSeverity, rhs: RiskSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .notice: return "Notice"
        case .caution: return "Caution"
        case .critical: return "Critical"
        }
    }
}

struct PreflightIssue: Identifiable, Equatable {
    let id = UUID()
    let itemID: UUID
    let fileName: String
    let severity: RiskSeverity
    let title: String
    let detail: String
}

struct RunSummary: Equatable {
    let total: Int
    let succeeded: Int
    let failed: Int
    let cancelled: Int
    let startedAt: Date
    let endedAt: Date

    var hasWork: Bool { total > 0 }

    var isClean: Bool {
        total > 0 && failed == 0 && cancelled == 0
    }

    var message: String {
        guard hasWork else { return "No queued jobs ran" }
        var parts: [String] = []
        if succeeded > 0 {
            parts.append("\(succeeded) succeeded")
        }
        if failed > 0 {
            parts.append("\(failed) failed")
        }
        if cancelled > 0 {
            parts.append("\(cancelled) cancelled")
        }
        return parts.isEmpty ? "No queued jobs ran" : parts.joined(separator: ", ")
    }
}
