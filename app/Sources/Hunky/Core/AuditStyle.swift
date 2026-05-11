import SwiftUI

/// Describes how a Redump aggregate state should be presented in the audit cell.
struct AuditStyle {
    let icon: String?
    let iconColor: Color
    let title: String
    let titleColor: Color
    let titleWeight: Font.Weight
    let meta: String?
}

extension FileItem.RedumpAggregate {
    /// Build the default audit style for this aggregate state.
    /// For `.corrupted`, pass the result of `corruptedMetaLine()` as `corruptedMeta`.
    func auditStyle(corruptedMeta: String? = nil) -> AuditStyle {
        switch self {
        case .verified(let identity):
            let platformName = RedumpDatabase.platformDisplayName(for: identity.platformKey)
            return AuditStyle(
                icon: "checkmark.seal.fill",
                iconColor: HunkyTheme.Redump.base,
                title: "\(platformName): \(identity.gameName)",
                titleColor: HunkyTheme.Redump.base,
                titleWeight: .medium,
                meta: "Redump, CRC match"
            )

        case .partial(let identities):
            let label = identities.count == 1
                ? "\(RedumpDatabase.platformDisplayName(for: identities[0].platformKey)): \(identities[0].gameName)"
                : "Partial Redump match"
            return AuditStyle(
                icon: "checkmark.circle",
                iconColor: HunkyTheme.Ink.secondary,
                title: label,
                titleColor: HunkyTheme.Ink.primary,
                titleWeight: .regular,
                meta: "Redump, partial match"
            )

        case .corrupted:
            return AuditStyle(
                icon: "exclamationmark.triangle.fill",
                iconColor: HunkyTheme.Severity.caution,
                title: "Track CRC mismatch",
                titleColor: HunkyTheme.Severity.caution,
                titleWeight: .medium,
                meta: corruptedMeta
            )

        case .unknown:
            return AuditStyle(
                icon: "questionmark.circle",
                iconColor: HunkyTheme.Ink.tertiary,
                title: "Not in Redump",
                titleColor: HunkyTheme.Ink.primary,
                titleWeight: .regular,
                meta: "unrecognized"
            )

        case .unavailable(let platform):
            return AuditStyle(
                icon: "questionmark.circle",
                iconColor: HunkyTheme.Ink.tertiary,
                title: "\(platform.rawValue) catalog not bundled",
                titleColor: HunkyTheme.Ink.primary,
                titleWeight: .regular,
                meta: "no offline DAT"
            )

        case .checking:
            return AuditStyle(
                icon: "dot.radiowaves.left.and.right",
                iconColor: HunkyTheme.Accent.base,
                title: "Running Ready Check",
                titleColor: HunkyTheme.Ink.secondary,
                titleWeight: .regular,
                meta: "hashing references…"
            )

        case .notApplicable:
            return AuditStyle(
                icon: nil,
                iconColor: .clear,
                title: "No track audit",
                titleColor: HunkyTheme.Ink.secondary,
                titleWeight: .regular,
                meta: nil
            )
        }
    }
}
