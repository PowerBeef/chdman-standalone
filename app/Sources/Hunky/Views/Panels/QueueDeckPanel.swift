import AppKit
import SwiftUI

struct QueueDeckPanel: View {
    @Bindable var queue: QueueController
    @Binding var searchText: String
    @Binding var cautionRibbonIssues: [PreflightIssue]
    let showPlatformBadges: Bool
    let onStartRequested: () -> Void
    let onStartAnywayRequested: () -> Void
    let onReviewCautionRibbon: () -> Void
    let onRevealInFinder: () -> Void
    let onShowInfo: (FileItem) -> Void
    let onShowLog: (FileItem) -> Void

    private var filteredItems: [FileItem] {
        guard !searchText.isEmpty else { return queue.items }
        let query = searchText.lowercased()
        return queue.items.filter { item in
            if item.displayName.lowercased().contains(query) { return true }
            if item.url.lastPathComponent.lowercased().contains(query) { return true }
            if let platform = item.identity?.platform?.rawValue.lowercased(), platform.contains(query) { return true }
            if item.action.label.lowercased().contains(query) { return true }
            if String(describing: item.status).lowercased().contains(query) { return true }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            queueHeader

            if queue.items.isEmpty {
                VStack(spacing: 0) {
                    QueueColumnHeader()
                    emptyQueue
                }
            } else {
                queueList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var queueHeader: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Queue")
                        .font(HunkyType.display)
                        .foregroundStyle(HunkyTheme.Ink.primary)
                    Text(queueStateText)
                        .font(HunkyType.label)
                        .foregroundStyle(HunkyTheme.Ink.tertiary)
                }

                Spacer()
            }

            if !searchText.isEmpty || queue.riskCount > 0 || queue.pendingCount > 0 {
                HStack(spacing: 10) {
                    if !searchText.isEmpty {
                        Label("Showing \(filteredItems.count) of \(queue.items.count)", systemImage: "line.3.horizontal.decrease.circle")
                    } else if queue.riskCount > 0 {
                        Label("\(queue.riskCount) Ready Check warning\(queue.riskCount == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(HunkyTheme.Severity.caution)
                    } else {
                        Label("Ready to run", systemImage: "checkmark.circle")
                            .foregroundStyle(HunkyTheme.Accent.base)
                    }
                    Spacer()
                }
                .font(HunkyType.status)
                .foregroundStyle(HunkyTheme.Ink.tertiary)
            }
        }
        .padding(.horizontal, HunkyLayout.queueRowLeadingPadding)
        .padding(.top, 29)
        .padding(.bottom, 21)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HunkyTheme.Hairline.base.opacity(0.64))
                .frame(height: 1)
        }
    }

    private var emptyQueue: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No disc images", systemImage: "opticaldisc")
                .font(HunkyType.headline)
                .foregroundStyle(HunkyTheme.Ink.primary)
            Text("Add CUE, GDI, TOC, ISO, or CHD files. Hunky runs a Ready Check before work starts.")
                .font(HunkyType.body)
                .foregroundStyle(HunkyTheme.Ink.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 540, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 72)
        .padding(.top, 118)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var queueList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if let summary = completedRunSummary {
                    CompletedRunChip(
                        summary: summary,
                        canRevealInFinder: hasRevealableOutput,
                        onRevealInFinder: onRevealInFinder
                    )
                    .padding(.horizontal, 28)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                    .transition(.opacity)
                }

                if !cautionRibbonIssues.isEmpty {
                    cautionRibbon
                        .padding(.horizontal, 28)
                        .padding(.top, 14)
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
            .padding(.bottom, 16)
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
            Text("Ready Check found \(count) caution\(count == 1 ? "" : "s") across \(itemCount) item\(itemCount == 1 ? "" : "s")")
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
                    .font(HunkyType.label2)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
            .accessibilityLabel("Dismiss caution ribbon")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .liquidGlassPanel(tint: HunkyTheme.Severity.cautionSoft, cornerRadius: 10, textureOpacity: 0)
    }

    private var queueStateText: String {
        if queue.isRunning {
            return "Running items sequentially"
        }
        if queue.pendingCount > 0 {
            return "\(queue.pendingCount) waiting"
        }
        if queue.finishedCount > 0 {
            return "All items finished"
        }
        return "Awaiting disc images"
    }
}
