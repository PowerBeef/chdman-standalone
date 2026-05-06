import AppKit
import SwiftUI

// MARK: - Run / summary state

enum HunkyRunState {
    /// Queue is empty.
    case none
    /// Queue has items, idle.
    case idle
    /// At least one job is in flight.
    case running
}

enum HunkySummaryKind {
    case ready
    case running
    case warn
}

struct HunkySummary {
    let kind: HunkySummaryKind
    let text: String
}

// MARK: - Custom titlebar
//
// 44pt strip across the top of the window with traffic-light reservation,
// grouped tb-buttons (Add / Run / overflow Menu) and a status summary chip
// pinned to the trailing edge. Replaces the macOS unified toolbar so the
// app's interior reads as one game-tool surface from top to bottom.

struct HunkyTitlebar<MenuContent: View>: View {
    let runState: HunkyRunState
    let summary: HunkySummary
    let onAdd: () -> Void
    let onAddFolder: () -> Void
    let onRun: () -> Void
    let onStop: () -> Void
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        ZStack(alignment: .leading) {
            // Drag handle covers the whole titlebar; controls layered on top.
            WindowDragHandle()

            HStack(spacing: 10) {
                // Reserve room for the OS-drawn traffic lights (top-left when the
                // window uses .hiddenTitleBar style). 78pt covers the close /
                // minimize / zoom triplet plus their padding.
                Spacer().frame(width: 78)

                divider

                tbGroup {
                    tbIconButton(systemImage: "plus", help: "Add files (⌘O)", action: onAdd)
                    tbDivider
                    tbIconButton(systemImage: "folder", help: "Add folder (⌘⇧O)", action: onAddFolder)
                }

                runButton

                overflowMenu

                Spacer()

                summaryChip
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 44)
        .background(HunkyTheme.titlebarFill)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HunkyTheme.hairline)
                .frame(height: 1)
        }
    }

    private var overflowMenu: some View {
        // Render the ellipsis + chevron as a single SF Symbol via the
        // builtin "ellipsis.circle"-adjacent approach: use a horizontal
        // glyph-string in a Text. SF Pro renders Unicode glyphs reliably
        // and SwiftUI's Menu doesn't fight Text labels the way it does
        // with HStacks of multiple Images.
        Menu {
            menuContent()
        } label: {
            (
                Text(Image(systemName: "ellipsis"))
                    .font(.system(size: 12, weight: .medium))
                + Text("  ")
                + Text(Image(systemName: "chevron.down"))
                    .font(.system(size: 9, weight: .semibold))
            )
            .foregroundStyle(HunkyTheme.inkSecondary)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .focusEffectDisabled()
        .focusable(false)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(HunkyTheme.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HunkyTheme.hairline, lineWidth: 1)
        )
        .help("More")
    }

    // MARK: Pieces

    private var divider: some View {
        Rectangle()
            .fill(HunkyTheme.hairlineStrong)
            .frame(width: 1, height: 20)
    }

    private var tbDivider: some View {
        Rectangle()
            .fill(HunkyTheme.hairline)
            .frame(width: 1, height: 16)
            .padding(.horizontal, 2)
    }

    private func tbGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 4) {
            content()
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(HunkyTheme.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HunkyTheme.hairline, lineWidth: 1)
        )
    }

    private func tbIconButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 26)
                .foregroundStyle(HunkyTheme.inkSecondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
    }

    private func tbButton(systemImage: String, label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 11.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 160, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .foregroundStyle(HunkyTheme.inkSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
    }

    @ViewBuilder
    private var runButton: some View {
        switch runState {
        case .none:
            runButtonLabel(systemImage: "play.fill", text: "Run queue", style: .disabled, action: {})
                .disabled(true)
        case .idle:
            runButtonLabel(systemImage: "play.fill", text: "Run queue", style: .primary, action: onRun)
        case .running:
            runButtonLabel(systemImage: "stop.fill", text: "Stop", style: .destructive, action: onStop)
        }
    }

    private enum RunButtonStyle { case primary, destructive, disabled }

    private func runButtonLabel(systemImage: String, text: String, style: RunButtonStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .frame(height: 26)
            .foregroundStyle(runFg(style))
            .background(runBg(style), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .keyboardShortcut(style == .destructive ? KeyboardShortcut(".", modifiers: .command) : KeyboardShortcut(.return, modifiers: .command))
        .help(style == .destructive ? "Stop running queue (⌘.)" : "Run queue (⌘↩)")
    }

    private func runBg(_ style: RunButtonStyle) -> Color {
        switch style {
        case .primary:     return HunkyTheme.accent
        case .destructive: return HunkyTheme.severityCritical
        case .disabled:    return HunkyTheme.surfaceSunken
        }
    }

    private func runFg(_ style: RunButtonStyle) -> Color {
        switch style {
        case .primary:     return Color(red: 0.02, green: 0.08, blue: 0.10)
        case .destructive: return Color(red: 0.10, green: 0.02, blue: 0.02)
        case .disabled:    return HunkyTheme.inkQuaternary
        }
    }

    private var summaryChip: some View {
        HStack(spacing: 8) {
            statusDot
            Text(summary.text)
                .font(.system(size: 11.5))
                .foregroundStyle(HunkyTheme.inkSecondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(HunkyTheme.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(HunkyTheme.hairline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusDot: some View {
        switch summary.kind {
        case .ready:
            dot(color: HunkyTheme.severityVerified, soft: HunkyTheme.severityVerifiedSoft)
        case .running:
            PulsingDot(color: HunkyTheme.accent, soft: HunkyTheme.accentSoft)
        case .warn:
            dot(color: HunkyTheme.severityCaution, soft: HunkyTheme.severityCautionSoft)
        }
    }

    private func dot(color: Color, soft: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .background(
                Circle().fill(soft).frame(width: 13, height: 13)
            )
    }
}

private struct PulsingDot: View {
    let color: Color
    let soft: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .background(
                Circle().fill(soft).frame(width: 13, height: 13)
            )
            .opacity(reduceMotion ? 1 : (animate ? 1.0 : 0.45))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: HunkyMotion.runningPulsePeriod / 2).repeatForever(autoreverses: true)
                ) {
                    animate = true
                }
            }
    }
}

// MARK: - Footer

struct HunkyFooter<Left: View, Right: View>: View {
    let left: Left
    let right: Right

    init(@ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.left = left()
        self.right = right()
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) { left }
            Spacer(minLength: 12)
            HStack(spacing: 12) { right }
        }
        .font(.system(size: 11))
        .foregroundStyle(HunkyTheme.inkTertiary)
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(HunkyTheme.footerFill)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(HunkyTheme.hairline)
                .frame(height: 1)
        }
    }
}

/// A right-aligned mono path label for the footer.
struct HunkyFooterPath: View {
    let text: String

    var body: some View {
        Text(text)
            .font(HunkyType.mono)
            .foregroundStyle(HunkyTheme.inkSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

// MARK: - Window drag handle

/// Marks an area as draggable via the underlying NSWindow. Used on the
/// custom titlebar so the user can drag the window from non-button regions.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DraggableNSView()
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class DraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
