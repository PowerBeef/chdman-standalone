import AppKit
import SwiftUI

struct QueueDeckPanel: View {
    @Bindable var queue: QueueController
    @Binding var cautionRibbonIssues: [PreflightIssue]
    let showPlatformBadges: Bool
    let onStartRequested: () -> Void
    let onStartAnywayRequested: () -> Void
    let onReviewCautionRibbon: () -> Void
    let onRevealInFinder: () -> Void
    let onShowInfo: (FileItem) -> Void
    let onShowLog: (FileItem) -> Void

    @State private var searchText = ""

    private var filteredItems: [FileItem] {
        guard !searchText.isEmpty else { return queue.items }
        let query = searchText.lowercased()
        return queue.items.filter { item in
            if item.displayName.lowercased().contains(query) { return true }
            if let platform = item.identity?.platform?.rawValue.lowercased(), platform.contains(query) { return true }
            if item.action.label.lowercased().contains(query) { return true }
            if String(describing: item.status).lowercased().contains(query) { return true }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            queueDeckHeader

            if queue.items.isEmpty {
                emptyQueueDeck
            } else {
                queueList
            }
        }
        .consolePanel(fill: HunkyTheme.Surface.consolePanelDeep, cornerRadius: 16, textureOpacity: 0.12)
    }

    private var queueDeckHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Queue Deck")
                    .font(HunkyType.title).fontWeight(.bold)
                    .foregroundStyle(HunkyTheme.Ink.primary)
                Text(queueStateText)
                    .font(HunkyType.label)
                    .foregroundStyle(HunkyTheme.Ink.tertiary)
            }

            if !queue.items.isEmpty {
                QueueSearchBar(
                    text: $searchText,
                    placeholder: "Filter slots…",
                    onClear: { searchText = "" }
                )
            }

            Spacer()

            if !queue.items.isEmpty || queue.isRunning {
                queueDeckRunControl
            }

            if !searchText.isEmpty {
                Text("Showing \(filteredItems.count) of \(queue.items.count)")
                    .font(HunkyType.label)
                    .foregroundStyle(HunkyTheme.Ink.tertiary)
            } else if queue.riskCount > 0 {
                Label("\(queue.riskCount) ready-check warning\(queue.riskCount == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                    .font(HunkyType.status)
                    .foregroundStyle(HunkyTheme.Severity.caution)
            } else if queue.pendingCount > 0 {
                Label("Ready to run", systemImage: "checkmark.seal")
                    .font(HunkyType.status)
                    .foregroundStyle(HunkyTheme.Accent.base)
            } else {
                Label("Waiting for discs", systemImage: "opticaldisc")
                    .font(HunkyType.status)
                    .foregroundStyle(HunkyTheme.Ink.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .liquidGlassPanel(tint: HunkyTheme.Glass.panelTint, cornerRadius: 0, textureOpacity: 0.02)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HunkyTheme.Hairline.base)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var queueDeckRunControl: some View {
        if queue.isRunning {
            Button {
                queue.cancel()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .font(HunkyType.sectionTitle)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(HunkyTheme.Severity.critical)
            .keyboardShortcut(".", modifiers: [.command])
            .help("Stop running queue (Command-.)")
            .accessibilityLabel("Stop queue")
        } else {
            Button {
                onStartRequested()
            } label: {
                Label("Run queue", systemImage: "play.fill")
                    .font(HunkyType.sectionTitle)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .tint(HunkyTheme.Accent.base)
            .disabled(queue.pendingCount == 0)
            .keyboardShortcut(.return, modifiers: [.command])
            .help("Run queue (Command-Return)")
            .accessibilityLabel("Run queue")
        }
    }

    private var emptyQueueDeck: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    PulsingLED(color: HunkyTheme.Memory.base, size: 8)
                    Text("No slots loaded")
                        .font(HunkyType.headline)
                        .foregroundStyle(HunkyTheme.Ink.primary)
                }
                Text("Drop disc images into the Disc Bay, or use Add Files or Folders. Hunky will choose the right action and run a Ready Check before the queue starts.")
                    .font(HunkyType.body)
                    .foregroundStyle(HunkyTheme.Ink.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 560, alignment: .leading)
            }

            HStack(spacing: 8) {
                ConsoleTag(text: "CUE")
                ConsoleTag(text: "GDI")
                ConsoleTag(text: "TOC")
                ConsoleTag(text: "ISO")
                ConsoleTag(text: "CHD")
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
    }

    private struct PulsingLED: View {
        let color: Color
        let size: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            TimelineView(.periodic(from: Date(), by: 0.05)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = sin(t * 2.5)
                let opacity = 0.5 + 0.5 * phase
                ConsoleLED(color: color, size: size)
                    .opacity(reduceMotion ? 1.0 : opacity)
            }
            .frame(width: size, height: size)
        }
    }

    private var queueList: some View {
        ScrollView {
            GlassEffectContainer(spacing: 8) {
                LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                    if let summary = completedRunSummary {
                        CompletedRunChip(
                            summary: summary,
                            canRevealInFinder: hasRevealableOutput,
                            onRevealInFinder: onRevealInFinder
                        )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                            .transition(.opacity)
                    }

                    if !cautionRibbonIssues.isEmpty {
                        cautionRibbon
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Section(header: QueueColumnHeader()) {
                        ForEach(filteredItems) { item in
                            QueueRow(
                                item: item,
                                isQueueRunning: queue.isRunning,
                                showPlatformBadge: showPlatformBadges,
                                onRemove: { queue.remove(item) },
                                onRetry: { queue.retry(item) },
                                onShowInfo: { onShowInfo(item) },
                                onShowLog: { onShowLog(item) }
                            )
                        }
                    }
                }
                .padding(12)
            }
        }
    }

    private var completedRunSummary: RunSummary? {
        guard !queue.isRunning,
              let summary = queue.lastRunSummary,
              summary.hasWork else { return nil }
        return summary
    }

    private var hasRevealableOutput: Bool {
        if queue.outputDirectory != nil { return true }
        return queue.items.contains { item in
            if case .done = item.status {
                return item.outputURL != nil
            }
            return false
        }
    }

    private var cautionRibbon: some View {
        let count = cautionRibbonIssues.count
        let itemCount = Set(cautionRibbonIssues.map(\.itemID)).count
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(HunkyTheme.Severity.caution)
            Text("Ready Check found \(count) caution\(count == 1 ? "" : "s") across \(itemCount) slot\(itemCount == 1 ? "" : "s")")
                .font(HunkyType.callout)
                .foregroundStyle(HunkyTheme.Ink.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Review") {
                onReviewCautionRibbon()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button("Start Anyway") {
                onStartAnywayRequested()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .tint(HunkyTheme.Severity.caution)
            Button {
                cautionRibbonIssues = []
            } label: {
                Image(systemName: "xmark")
                    .font(HunkyType.label2).fontWeight(.semibold)
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
            .accessibilityLabel("Dismiss caution ribbon")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .liquidGlassPanel(tint: HunkyTheme.Severity.cautionSoft, cornerRadius: 8, textureOpacity: 0.03)
    }

    private var queueStateText: String {
        if queue.isRunning {
            return "Running slots sequentially"
        }
        if queue.pendingCount > 0 {
            return "\(queue.pendingCount) waiting in deck"
        }
        if queue.finishedCount > 0 {
            return "All slots finished"
        }
        return "Awaiting disc images"
    }
}
