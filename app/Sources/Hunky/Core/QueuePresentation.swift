import Foundation

struct IntakeResult: Equatable, Sendable {
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

enum RiskSeverity: Int, Comparable, Equatable, Sendable {
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

struct PreflightIssue: Identifiable, Equatable, Sendable {
    let id = UUID()
    let itemID: UUID
    let fileName: String
    let severity: RiskSeverity
    let title: String
    let detail: String
}

enum ReadyCheckStartDecision: Equatable, Sendable {
    case start
    case showCautionRibbon
    case showSheet
}

enum ReadyCheckPolicy {
    static func decisionForStart(issues: [PreflightIssue], confirmBeforeRun: Bool) -> ReadyCheckStartDecision {
        if issues.contains(where: { $0.severity == .critical }) {
            return .showSheet
        }
        if confirmBeforeRun {
            return .showSheet
        }
        return issues.isEmpty ? .start : .showCautionRibbon
    }

    static func decisionAfterCautionReview(issues: [PreflightIssue], confirmBeforeRun: Bool) -> ReadyCheckStartDecision {
        if issues.contains(where: { $0.severity == .critical }) || confirmBeforeRun {
            return .showSheet
        }
        return .start
    }
}

struct ReadyCheckCopy: Equatable, Sendable {
    let issues: [PreflightIssue]

    var hasCritical: Bool {
        issues.contains { $0.severity == .critical }
    }

    var criticalCount: Int {
        issues.filter { $0.severity == .critical }.count
    }

    var criticalItemCount: Int {
        Set(issues.filter { $0.severity == .critical }.map(\.itemID)).count
    }

    var cautionCount: Int {
        issues.filter { $0.severity == .caution }.count
    }

    var headlineText: String {
        if hasCritical {
            return "\(criticalItemCount) slot\(criticalItemCount == 1 ? " needs" : "s need") attention"
        }
        if issues.isEmpty {
            return "Ready Check is clear"
        }
        return "Review \(issues.count) item\(issues.count == 1 ? "" : "s") before starting"
    }

    var paragraphText: String {
        if hasCritical {
            let cautionSuffix: String
            if cautionCount > 0 {
                let verb = cautionCount == 1 ? "needs" : "need"
                cautionSuffix = " \(cautionCount) caution\(cautionCount == 1 ? "" : "s") also \(verb) review."
            } else {
                cautionSuffix = ""
            }
            return "Hunky found \(criticalCount) critical issue\(criticalCount == 1 ? "" : "s") across \(criticalItemCount) slot\(criticalItemCount == 1 ? "" : "s"). The queue can start, but affected jobs are likely to fail or produce unsafe output.\(cautionSuffix)"
        }
        if issues.isEmpty {
            return "There are no current blockers or cautions for pending slots."
        }
        return "These jobs can still run, but the Ready Check found issues that may produce bad output or fail."
    }

    var confirmButtonTitle: String {
        issues.isEmpty ? "Start queue" : "Start anyway"
    }
}

struct RunSummary: Equatable, Sendable {
    let total: Int
    let succeeded: Int
    let created: Int
    let extracted: Int
    let inspected: Int
    let verified: Int
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
            parts.append(successBreakdown)
        }
        if failed > 0 {
            parts.append("\(failed) failed")
        }
        if cancelled > 0 {
            parts.append("\(cancelled) cancelled")
        }
        return parts.isEmpty ? "No queued jobs ran" : parts.joined(separator: ", ")
    }

    var successBreakdown: String {
        var parts: [String] = []
        if created > 0 {
            parts.append("\(created) created")
        }
        if extracted > 0 {
            parts.append("\(extracted) extracted")
        }
        if inspected > 0 {
            parts.append("\(inspected) inspected")
        }
        if verified > 0 {
            parts.append("\(verified) verified")
        }
        return parts.isEmpty ? "\(succeeded) succeeded" : parts.joined(separator: ", ")
    }
}
