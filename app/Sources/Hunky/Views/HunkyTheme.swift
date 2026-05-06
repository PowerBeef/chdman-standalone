import AppKit
import SwiftUI

// MARK: - Design tokens
//
// Hunky's interior is deliberately macOS-native: system semantic colors,
// system-typographic body, severity colors only when something matters.
// The token names are semantic so call sites read intent rather than picking
// pixels. Mono is reserved for genuinely code-shaped content (chdman process
// output inside the Info / Log sheets).

enum HunkyTheme {
    // MARK: - Surfaces (system semantic colors)

    /// Window background. Adapts automatically to light/dark and to the user's
    /// graphite/blue/etc. accent settings.
    static let surface = Color(nsColor: .windowBackgroundColor)

    /// Recessed areas: running-row tint, popover bodies, drag-state highlight.
    static let surfaceMuted = Color(nsColor: .controlBackgroundColor)

    /// 1pt row dividers and quiet borders. Same value the system uses elsewhere.
    static let hairline = Color(nsColor: .separatorColor)

    // MARK: - Ink

    static let inkPrimary: Color = .primary
    static let inkSecondary: Color = .secondary
    static let inkTertiary = Color(nsColor: .tertiaryLabelColor)

    // MARK: - Action

    /// Primary action surfaces. Inherits the user's System Settings accent.
    static let accent: Color = .accentColor

    // MARK: - Severity

    /// Caution: warnings the user should review before running.
    static let severityCaution = Color(nsColor: .systemYellow)
    /// Critical: errors and almost-certain failures.
    static let severityCritical = Color(nsColor: .systemRed)
    /// Verified: Redump CRC matches and successful job completion only. Do not
    /// use for "no warnings" or file-presence checks — those use `inkSecondary`.
    static let severityVerified = Color(nsColor: .systemGreen)

    static func severityColor(_ severity: RiskSeverity) -> Color {
        switch severity {
        case .notice:   return inkSecondary
        case .caution:  return severityCaution
        case .critical: return severityCritical
        }
    }
}

// MARK: - Typography tokens
//
// System-typographic by default. Mono is reserved for `HunkyType.mono`,
// which is only used inside `TextOutputSheet` for chdman's stdout/stderr.

enum HunkyType {
    /// Headlines: queue overview, sheet titles.
    static let title: Font = .system(.title3, design: .default).weight(.semibold)
    /// Body text — proportional system face.
    static let body: Font = .system(.body)
    /// Captions.
    static let label: Font = .system(.caption)
    /// Smallest tier. Chips, micro-labels.
    static let label2: Font = .system(.caption2)
    /// Monospaced. Reserved for chdman's raw process output inside Info / Log sheets.
    static let mono: Font = .system(.body, design: .monospaced)
}

// MARK: - Motion tokens

enum HunkyMotion {
    /// Snap transition for row state changes and disclosure expansion.
    /// Honor `accessibilityReduceMotion` at the call site by passing `nil` instead.
    static let snap: Animation = .easeOut(duration: 0.18)
    /// Period of the running-progress shimmer sweep (seconds). Implemented
    /// via `TimelineView` at the call site so reduce-motion can disable it.
    static let shimmerPeriod: TimeInterval = 1.6
}
