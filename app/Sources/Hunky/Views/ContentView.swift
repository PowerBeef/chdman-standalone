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

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

            Divider()

            if queue.items.isEmpty {
                emptyState
            } else {
                queueList
            }

            Divider()
            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .background(HunkyTheme.surface)
        .frame(minWidth: 700, minHeight: 500)
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
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(HunkyTheme.retroBlue.opacity(0.14))
                Image(systemName: "opticaldisc.fill")
                    .font(.title3)
                    .foregroundStyle(HunkyTheme.retroBlue)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text("Hunky")
                    .font(.title3.weight(.semibold))
                Text("Self-contained CHD workbench")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !queue.items.isEmpty {
                HStack(spacing: 6) {
                    summaryChip("\(queue.items.count)", "items", systemImage: "tray.full")
                    if queue.pendingCount > 0 {
                        summaryChip("\(queue.pendingCount)", "ready", systemImage: "play.circle")
                    }
                    if queue.riskCount > 0 {
                        summaryChip("\(queue.riskCount)", "need review", systemImage: "exclamationmark.triangle", tint: HunkyTheme.amber)
                    }
                }
                .padding(.leading, 6)
            }

            Spacer()

            if !queue.items.isEmpty {
                Button {
                    queue.clear()
                } label: {
                    Label("Clear finished", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(!queue.items.contains(where: isFinished))
                .help("Remove completed, failed, and cancelled jobs")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if let intakeMessage {
                statusBanner(text: intakeMessage, systemImage: "info.circle", tint: HunkyTheme.retroBlue)
            }

            DropZone(isCompact: false) { urls in
                recordIntake(queue.add(urls: urls))
            }
        }
        .padding(20)
    }

    private var queueList: some View {
        ScrollView {
            VStack(spacing: 10) {
                queueOverview

                ForEach(queue.items) { item in
                    QueueRow(
                        item: item,
                        isQueueRunning: queue.isRunning,
                        onRemove: { queue.remove(item) },
                        onRetry: { queue.retry(item) },
                        onShowInfo: { infoItem = item },
                        onShowLog: { logItem = item }
                    )
                }

                DropZone(isCompact: true) { urls in
                    recordIntake(queue.add(urls: urls))
                }
                .padding(.top, 2)
            }
            .padding(20)
        }
    }

    private var queueOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Queue")
                    .font(.headline)
                Text(queueStateText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if queue.riskCount > 0 {
                    Label("\(queue.riskCount) need review", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(HunkyTheme.amber)
                } else if queue.pendingCount > 0 {
                    Label("Ready to run", systemImage: "checkmark.seal")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(HunkyTheme.verifiedGreen)
                }
            }

            if let intakeMessage {
                statusBanner(text: intakeMessage, systemImage: "tray.and.arrow.down", tint: HunkyTheme.retroBlue)
            }
        }
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

    private var footer: some View {
        HStack(spacing: 14) {
            outputDirControl
            Spacer(minLength: 12)
            if let summary = queue.lastRunSummary, summary.hasWork {
                Label(summary.message, systemImage: summary.isClean ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(summary.isClean ? HunkyTheme.verifiedGreen : HunkyTheme.amber)
                    .lineLimit(1)
            }
            primaryButton
        }
    }

    private var outputDirControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(HunkyTheme.subtleInk)
            Text("Output")
                .foregroundStyle(.secondary)
            Text(outputLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 250, alignment: .leading)
            Button {
                pickOutputDirectory()
            } label: {
                Text(queue.outputDirectory == nil ? "Choose..." : "Change...")
            }
            .help("Choose an output folder")
            if queue.outputDirectory != nil {
                Button {
                    queue.outputDirectory = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Reset to source folder")
                .accessibilityLabel("Reset output folder")
            }
        }
        .font(.callout)
    }

    private var outputLabel: String {
        if let dir = queue.outputDirectory {
            return dir.path(percentEncoded: false)
        }
        return "Same folder as source"
    }

    @ViewBuilder
    private var primaryButton: some View {
        if queue.isRunning {
            Button(role: .destructive) {
                queue.cancel()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .frame(minWidth: 96)
            }
            .controlSize(.large)
            .keyboardShortcut(".", modifiers: [.command])
        } else {
            Button {
                startRequested()
            } label: {
                Label(queue.riskCount > 0 ? "Review & Start" : "Start", systemImage: queue.riskCount > 0 ? "exclamationmark.triangle.fill" : "play.fill")
                    .frame(minWidth: 112)
            }
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(queue.pendingCount == 0)
            .buttonStyle(.borderedProminent)
            .tint(queue.riskCount > 0 ? HunkyTheme.amber : HunkyTheme.retroBlue)
        }
    }

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
        if issues.isEmpty {
            queue.start()
        } else {
            preflightIssues = issues
            isShowingPreflight = true
        }
    }

    private func recordIntake(_ result: IntakeResult) {
        intakeMessage = result.message
    }

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

    private func summaryChip(_ value: String, _ label: String, systemImage: String, tint: Color = HunkyTheme.retroBlue) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .imageScale(.small)
            Text(value)
                .monospacedDigit()
                .fontWeight(.semibold)
            Text(label)
        }
        .font(.caption)
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.11), in: Capsule())
    }

    private func statusBanner(text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .lineLimit(2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.09))
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

private struct PreflightConfirmationSheet: View {
    let issues: [PreflightIssue]
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(HunkyTheme.amber)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review before starting")
                        .font(.headline)
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
                    .tint(HunkyTheme.amber)
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
                        .font(.caption.weight(.semibold))
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
                    .font(.callout.weight(.medium))
                Text(issue.detail)
                    .font(.caption)
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
                    Text(title).font(.headline)
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
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
        .frame(minWidth: 560, minHeight: 380)
    }
}
