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
// 36pt strip across the top of the window. Brings the button-row vertical
// center within ~6pt of the OS-drawn traffic lights so the chrome reads as a
// single eye-line. All elements are left-anchored; the right side of the
// strip is a clean drag region. Replaces the macOS unified toolbar so the
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

            HStack(spacing: 8) {
                // Reserve room for the OS-drawn traffic lights (top-left when the
                // window uses .hiddenTitleBar style). 78pt covers the close /
                // minimize / zoom triplet plus their padding.
                Spacer().frame(width: 78)

                tbGroup {
                    tbIconButton(systemImage: "plus", help: "Add files (⌘O)", action: onAdd)
                    tbDivider
                    tbIconButton(systemImage: "folder", help: "Add folder (⌘⇧O)", action: onAddFolder)
                }

                runButton

                overflowMenu

                summaryChip

                // Trailing drag region — empty space the user can grab to move
                // the window. The previous design pinned the summary chip to
                // the far right with a Spacer in front; at wide window widths
                // that left the action cluster marooned. Left-anchoring all
                // chrome and using the tail as drag space reads tighter.
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 26)
        .background(HunkyTheme.titlebarFill)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HunkyTheme.hairline)
                .frame(height: 1)
        }
    }

    private var overflowMenu: some View {
        // Render the ellipsis + chevron as a single Text with embedded SF
        // Symbols. SwiftUI's Menu fights HStacks-of-Images inside its label
        // (the second image gets clipped by the borderlessButton style); the
        // text-attribute path renders both glyphs reliably.
        Menu {
            menuContent()
        } label: {
            (
                Text(Image(systemName: "ellipsis"))
                    .font(.system(size: 11.5, weight: .medium))
                + Text("  ")
                + Text(Image(systemName: "chevron.down"))
                    .font(.system(size: 9, weight: .semibold))
            )
            .foregroundStyle(HunkyTheme.inkSecondary)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .focusEffectDisabled()
        .focusable(false)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(HunkyTheme.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(HunkyTheme.hairline, lineWidth: 1)
        )
        .help("More")
    }

    // MARK: Pieces

    private var tbDivider: some View {
        Rectangle()
            .fill(HunkyTheme.hairline)
            .frame(width: 1, height: 14)
            .padding(.horizontal, 1)
    }

    private func tbGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 4) {
            content()
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(HunkyTheme.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(HunkyTheme.hairline, lineWidth: 1)
        )
    }

    private func tbIconButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11.5, weight: .medium))
                .frame(width: 22, height: 22)
                .foregroundStyle(HunkyTheme.inkSecondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
    }

    /// Hidden when there's nothing to run. The previous "transparent dim text"
    /// disabled state read as an orphan element floating between two grouped
    /// clusters; dropping it entirely makes the empty-state chrome cleaner
    /// and re-introduces the cyan / red pill the moment a job is queued.
    @ViewBuilder
    private var runButton: some View {
        switch runState {
        case .none:
            EmptyView()
        case .idle:
            runButtonLabel(systemImage: "play.fill", text: "Run queue", style: .primary, action: onRun)
        case .running:
            runButtonLabel(systemImage: "stop.fill", text: "Stop", style: .destructive, action: onStop)
        }
    }

    private enum RunButtonStyle { case primary, destructive }

    private func runButtonLabel(systemImage: String, text: String, style: RunButtonStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(text)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .frame(height: 22)
            .foregroundStyle(runFg(style))
            .background(runBg(style), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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
        }
    }

    private func runFg(_ style: RunButtonStyle) -> Color {
        switch style {
        case .primary:     return Color(red: 0.02, green: 0.08, blue: 0.10)
        case .destructive: return Color(red: 0.10, green: 0.02, blue: 0.02)
        }
    }

    private var summaryChip: some View {
        HStack(spacing: 7) {
            statusDot
            Text(summary.text)
                .font(.system(size: 11))
                .foregroundStyle(HunkyTheme.inkSecondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(HunkyTheme.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
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
            .frame(width: 6, height: 6)
            .background(
                Circle().fill(soft).frame(width: 11, height: 11)
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
            .frame(width: 6, height: 6)
            .background(
                Circle().fill(soft).frame(width: 11, height: 11)
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

// MARK: - Window drag handle / titlebar configuration

/// Marks an area as draggable via the underlying NSWindow AND configures the
/// host window so SwiftUI content extends into the title-bar region. Without
/// `.fullSizeContentView` in the style mask, the OS reserves a ~28pt strip at
/// the top for the (hidden) title bar; traffic lights sit inside that strip
/// while our custom content starts below it, producing visible vertical
/// misalignment between the traffic lights and the button row. Setting
/// `titlebarAppearsTransparent = true` and inserting `.fullSizeContentView`
/// makes the content area cover y=0 of the window so the lights overlay our
/// titlebar's leading edge instead of floating above it.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableNSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
    }
}

private final class DraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
