import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var queue = QueueController()
    @State private var infoItem: FileItem?
    @State private var logItem: FileItem?
    @State private var intakeMessage: String?
    @State private var preflightIssues: [PreflightIssue] = []
    @State private var isShowingPreflight = false
    @State private var cautionRibbonIssues: [PreflightIssue] = []
    @State private var isWindowDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            HunkyTitlebar(
                runState: runState,
                summary: titlebarSummary,
                onAdd: pickFiles,
                onRun: startRequested,
                onStop: { queue.cancel() },
                outputLabel: outputToolbarLabel,
                onPickOutput: pickOutputDirectory,
                menuContent: { overflowMenuItems }
            )

            if queue.items.isEmpty {
                emptyState
            } else {
                queueList
            }

            HunkyFooter(
                left: { footerLeft },
                right: { footerRight }
            )
        }
        .background(HunkyTheme.surface)
        .frame(minWidth: 880, minHeight: 600)
        .onDrop(of: [.fileURL], isTargeted: $isWindowDropTargeted, perform: handleWindowDrop)
        .sheet(item: $infoItem) { item in
            InfoSheet(item: item)
        }
        .sheet(item: $logItem) { item in
            LogSheet(item: item)
        }
        .sheet(isPresented: $isShowingPreflight) {
            PreflightConfirmationSheet(
                issues: preflightIssues,
                onCancel: { isShowingPreflight = false },
                onConfirm: {
                    isShowingPreflight = false
                    queue.start()
                }
            )
        }
        .focusedSceneValue(\.hunkyCommands, commandActions)
        .onChange(of: queue.items.count) { _, _ in
            // Items added or removed invalidate any cached preflight notice.
            cautionRibbonIssues = []
        }
        .onChange(of: queue.isRunning) { _, isRunning in
            if isRunning { cautionRibbonIssues = [] }
        }
    }

    // MARK: - Run state / summary

    private var runState: HunkyRunState {
        if queue.isRunning { return .running }
        if queue.items.isEmpty { return .none }
        return .idle
    }

    private var titlebarSummary: HunkySummary {
        if queue.isRunning {
            let total = queue.items.count
            let completed = queue.items.filter { item in
                if case .done = item.status { return true }
                return false
            }.count
            return HunkySummary(kind: .running, text: "\(completed) of \(total) running")
        }
        if queue.riskCount > 0 {
            let n = queue.riskCount
            return HunkySummary(kind: .warn, text: "\(queue.items.count) queued · \(n) warning\(n == 1 ? "" : "s")")
        }
        if queue.items.isEmpty {
            return HunkySummary(kind: .ready, text: "No items")
        }
        return HunkySummary(kind: .ready, text: "\(queue.items.count) queued")
    }

    @ViewBuilder
    private var overflowMenuItems: some View {
        Button("Retry Failed") { queue.retryFailed() }
            .disabled(!commandActions.canRetryFailed)
        Button("Clear Finished") { queue.clear() }
            .disabled(!commandActions.canClearFinished)
        if queue.outputDirectory != nil {
            Divider()
            Button("Reset Output to Source") { queue.outputDirectory = nil }
        }
    }

    private var footerLeft: some View {
        Group {
            if let summary = queue.lastRunSummary, summary.hasWork {
                Label(summary.message, systemImage: summary.isClean ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(summary.isClean ? HunkyTheme.severityVerified : HunkyTheme.severityCaution)
                    .font(.system(size: 11))
                    .lineLimit(1)
            } else if !queue.items.isEmpty {
                Text("\(queue.items.count) item\(queue.items.count == 1 ? "" : "s") in queue")
            } else {
                Text("Nothing queued")
            }
        }
    }

    private var footerRight: some View {
        HStack(spacing: 6) {
            Text("Output")
            HunkyFooterPath(text: outputFooterLabel)
        }
        .help(outputLabelLong)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            if let intakeMessage {
                statusBanner(text: intakeMessage, systemImage: "info.circle", tint: .accentColor)
            }
            DropZone(
                onDrop: { urls in recordIntake(queue.add(urls: urls)) },
                isDropping: isWindowDropTargeted
            )
            Text("Tip: drop a folder of CDs and Hunky picks the right action per file.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Queue list

    private var queueList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                queueOverview
                    .padding(.horizontal, QueueColumns.rowHorizontalPadding)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                if !cautionRibbonIssues.isEmpty {
                    cautionRibbon
                        .padding(.horizontal, QueueColumns.rowHorizontalPadding)
                        .padding(.bottom, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Section(header: QueueColumnHeader()) {
                    let items = queue.items
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 0) {
                            QueueRow(
                                item: item,
                                isQueueRunning: queue.isRunning,
                                onRemove: { queue.remove(item) },
                                onRetry: { queue.retry(item) },
                                onShowInfo: { infoItem = item },
                                onShowLog: { logItem = item }
                            )
                            if index < items.count - 1 {
                                Rectangle()
                                    .fill(HunkyTheme.hairline)
                                    .frame(height: 1)
                                    .padding(.horizontal, QueueColumns.rowHorizontalPadding)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 14)
        }
    }

    private var queueOverview: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Queue")
                .font(HunkyType.title)
                .foregroundStyle(.primary)
            Text(queueStateText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            if queue.riskCount > 0 {
                Label("\(queue.riskCount) need review", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(HunkyTheme.severityCaution)
            } else if queue.pendingCount > 0 {
                Label("Ready to run", systemImage: "checkmark.seal")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(HunkyTheme.severityVerified)
            }
        }
    }

    private var cautionRibbon: some View {
        let count = cautionRibbonIssues.count
        let itemCount = Set(cautionRibbonIssues.map(\.itemID)).count
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(HunkyTheme.severityCaution)
            Text("\(count) caution\(count == 1 ? "" : "s") across \(itemCount) item\(itemCount == 1 ? "" : "s") before starting")
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Review") {
                preflightIssues = cautionRibbonIssues
                isShowingPreflight = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button("Start Anyway") {
                cautionRibbonIssues = []
                queue.start()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(HunkyTheme.severityCaution)
            Button {
                cautionRibbonIssues = []
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
            .accessibilityLabel("Dismiss caution ribbon")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(HunkyTheme.severityCaution.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HunkyTheme.severityCaution.opacity(0.30), lineWidth: 1)
        )
    }

    private var queueStateText: String {
        if queue.isRunning {
            return "Running sequentially"
        }
        if queue.pendingCount > 0 {
            return "\(queue.pendingCount) waiting"
        }
        if queue.finishedCount > 0 {
            return "All jobs finished"
        }
        return "Ready"
    }

    // MARK: - Output popover

    private var outputToolbarLabel: String {
        if let dir = queue.outputDirectory {
            return dir.lastPathComponent
        }
        return "Same as source"
    }

    private var outputFooterLabel: String {
        if let dir = queue.outputDirectory {
            return dir.lastPathComponent
        }
        return "Same folder as source"
    }

    private var outputLabelLong: String {
        if let dir = queue.outputDirectory {
            return dir.path(percentEncoded: false)
        }
        return "Same folder as source"
    }

    // MARK: - Commands wiring

    private var commandActions: HunkyCommandActions {
        HunkyCommandActions(
            addFiles: pickFiles,
            chooseOutput: pickOutputDirectory,
            start: startRequested,
            stop: { queue.cancel() },
            clearFinished: { queue.clear() },
            retryFailed: { queue.retryFailed() },
            canStart: !queue.isRunning && queue.pendingCount > 0,
            canStop: queue.isRunning,
            canClearFinished: queue.items.contains(where: isFinished),
            canRetryFailed: !queue.isRunning && queue.items.contains(where: isRetryable)
        )
    }

    private func startRequested() {
        let issues = queue.preflightIssuesForPendingItems()
        cautionRibbonIssues = []
        if issues.isEmpty {
            queue.start()
            return
        }
        let hasCritical = issues.contains { $0.severity == .critical }
        if hasCritical {
            preflightIssues = issues
            isShowingPreflight = true
        } else {
            // Caution-only — surface as inline ribbon, no modal interrupt.
            cautionRibbonIssues = issues
        }
    }

    private func recordIntake(_ result: IntakeResult) {
        intakeMessage = result.message
    }

    // MARK: - File pickers

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "chd") ?? .data,
            UTType(filenameExtension: "cue") ?? .data,
            UTType(filenameExtension: "gdi") ?? .data,
            UTType(filenameExtension: "iso") ?? .data,
            UTType(filenameExtension: "toc") ?? .data,
        ]
        panel.prompt = "Add"
        if panel.runModal() == .OK {
            recordIntake(queue.add(urls: panel.urls))
        }
    }

    private func pickOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            queue.outputDirectory = url
        }
    }

    // MARK: - Window-level drop

    private func handleWindowDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for p in providers {
            group.enter()
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.isFileURL {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            lock.lock()
            let dropped = urls
            lock.unlock()
            if !dropped.isEmpty {
                recordIntake(queue.add(urls: dropped))
            }
        }
        return true
    }

    // MARK: - Status helpers

    private func statusBanner(text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .lineLimit(2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }

    private func isFinished(_ item: FileItem) -> Bool {
        switch item.status {
        case .done, .failed, .cancelled: return true
        case .idle, .running:            return false
        }
    }

    private func isRetryable(_ item: FileItem) -> Bool {
        switch item.status {
        case .failed, .cancelled: return true
        case .idle, .running, .done: return false
        }
    }
}

// MARK: - Sheets

private struct PreflightConfirmationSheet: View {
    let issues: [PreflightIssue]
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(HunkyTheme.severityCaution)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review before starting")
                        .font(HunkyType.title)
                    Text("These jobs can still run, but Hunky found issues that may produce bad output or fail.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(issues) { issue in
                        issueRow(issue)
                    }
                }
                .padding(18)
            }
            .frame(minHeight: 220)

            Divider()

            HStack {
                Text("\(issues.count) issue\(issues.count == 1 ? "" : "s") across \(Set(issues.map(\.itemID)).count) queued item\(Set(issues.map(\.itemID)).count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Start Anyway", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(HunkyTheme.severityCaution)
            }
            .padding(18)
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    private func issueRow(_ issue: PreflightIssue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: issue.severity == .critical ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(HunkyTheme.severityColor(issue.severity))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(issue.fileName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(issue.severity.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(HunkyTheme.severityColor(issue.severity))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(HunkyTheme.severityColor(issue.severity).opacity(0.12), in: Capsule())
                }
                Text(issue.title)
                    .font(.body.weight(.medium))
                Text(issue.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct InfoSheet: View {
    let item: FileItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TextOutputSheet(
            title: item.displayName,
            subtitle: "CHD info",
            text: item.infoOutput ?? "(no output)",
            done: { dismiss() }
        )
    }
}

private struct LogSheet: View {
    let item: FileItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TextOutputSheet(
            title: item.displayName,
            subtitle: "Process log",
            text: item.logOutput ?? "(no log output)",
            done: { dismiss() }
        )
    }
}

private struct TextOutputSheet: View {
    let title: String
    let subtitle: String
    let text: String
    let done: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(HunkyType.title)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button("Done", action: done)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            Divider()
            ScrollView {
                Text(text)
                    .font(HunkyType.mono)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
        .frame(minWidth: 560, minHeight: 380)
    }
}
