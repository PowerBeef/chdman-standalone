import AppKit
import SwiftUI

struct ContentView: View {
    var settings: AppSettings

    @State private var queue = QueueController()
    @State private var infoItem: FileItem?
    @State private var logItem: FileItem?
    @State private var intakeMessage: String?
    @State private var preflightSheet: PreflightSheetPayload?
    @State private var cautionRibbonIssues: [PreflightIssue] = []
    @State private var isWindowDropTargeted = false

    var body: some View {
        ZStack(alignment: .top) {
            ConsoleTextureBackground(opacity: 0.16)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 54)

                workbench

                Spacer(minLength: 0)

                HunkyFooter(
                    left: { footerLeft },
                    right: { footerRight }
                )
                .frame(height: 34)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if isWindowDropTargeted {
                WindowDropOverlay()
            }
        }
        .background(HunkyTheme.Surface.base)
        .frame(minWidth: 880, minHeight: 600, alignment: .top)
        .onDrop(of: [.fileURL], isTargeted: $isWindowDropTargeted, perform: handleWindowDrop)
        .toolbar { toolbarContent }
        .sheet(item: $infoItem) { item in
            InfoSheet(item: item)
        }
        .sheet(item: $logItem) { item in
            LogSheet(item: item)
        }
        .sheet(item: $preflightSheet) { payload in
            PreflightConfirmationSheet(
                issues: payload.issues,
                onCancel: { preflightSheet = nil },
                onConfirm: {
                    preflightSheet = nil
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
            if isRunning {
                cautionRibbonIssues = []
                AppIntegration.requestNotificationAuthorization()
                AppIntegration.updateDockBadge(running: 1, pending: queue.pendingCount)
            } else {
                AppIntegration.updateDockBadge()
            }
        }
        .onChange(of: queue.lastRunSummary) { _, summary in
            guard let summary else { return }
            if settings.soundEnabled {
                AppIntegration.playCompletionSound(success: summary.isClean)
            }
            AppIntegration.postQueueCompletion(summary: summary)
            if settings.autoRetryFailed && summary.failed > 0 && !queue.isRunning {
                queue.retryFailed()
                queue.start()
            }
        }
        .onChange(of: settings.outputDirectory) { _, directory in
            if queue.outputDirectory != directory {
                queue.outputDirectory = directory
            }
        }
        .onAppear {
            queue.outputDirectory = settings.outputDirectory
        }
    }

    @ViewBuilder
    private var overflowMenuItems: some View {
        Button("Retry Failed") { queue.retryFailed() }
            .disabled(!commandActions.canRetryFailed)
        Button("Clear Finished") { queue.clear() }
            .disabled(!commandActions.canClearFinished)
        Divider()
        Button("Choose Save Path...") { pickOutputDirectory() }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        if queue.outputDirectory != nil {
            Button("Reset Save Path to Source") {
                queue.outputDirectory = nil
                settings.outputDirectory = nil
            }
        }
    }

    // MARK: - Toolbar
    //
    // Native macOS unified toolbar. Traffic lights and toolbar items share
    // the same eye-line by OS guarantee. Queue state stays inside the workbench.

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                pickFiles()
            } label: {
                Image(systemName: "plus")
            }
            .help("Add files or folders (Command-O)")
            .accessibilityLabel("Add files or folders")
        }

        ToolbarItem(placement: .navigation) {
            Menu {
                overflowMenuItems
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuIndicator(.hidden)
            .help("More")
        }
    }

    private var footerLeft: some View {
        HStack(spacing: 7) {
            if let summary = queue.lastRunSummary, summary.hasWork {
                ConsoleLED(color: summary.isClean ? HunkyTheme.Severity.verified : HunkyTheme.Severity.caution, size: 7)
                Label(summary.message, systemImage: summary.isClean ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(summary.isClean ? HunkyTheme.Severity.verified : HunkyTheme.Severity.caution)
                    .font(HunkyType.label)
                    .lineLimit(1)
            } else if !queue.items.isEmpty {
                ConsoleLED(color: queue.isRunning ? HunkyTheme.Accent.base : HunkyTheme.Memory.base, size: 7)
                Text("\(queue.items.count) slot\(queue.items.count == 1 ? "" : "s") loaded")
            } else {
                ConsoleLED(color: HunkyTheme.Ink.quaternary, size: 7, isLit: false)
                Text("Queue deck empty")
            }
        }
    }

    private var footerRight: some View {
        HStack(spacing: 8) {
            Text("Save path")

            outputFooterValue

            Button("Choose...") {
                pickOutputDirectory()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(HunkyTheme.Ink.tertiary)
            .font(HunkyType.formatChip)
            .help("Choose output folder (Command-Shift-O)")
            .accessibilityLabel("Choose output folder")
        }
        .help(outputLabelLong)
    }

    @ViewBuilder
    private var outputFooterValue: some View {
        if let dir = queue.outputDirectory {
            HunkyFooterPath(text: dir.path(percentEncoded: false))
                .frame(maxWidth: 360, alignment: .trailing)
        } else {
            Text("Same folder as source")
                .font(HunkyType.status)
                .foregroundStyle(HunkyTheme.Ink.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Workbench shell

    private var workbench: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                DiscBayPanel(
                    queue: queue,
                    intakeMessage: intakeMessage,
                    onPickOutputDirectory: pickOutputDirectory,
                    onAddFiles: addFiles
                )
                .frame(width: 304)

                QueueDeckPanel(
                    queue: queue,
                    cautionRibbonIssues: $cautionRibbonIssues,
                    showPlatformBadges: settings.showPlatformBadges,
                    onStartRequested: startRequested,
                    onStartAnywayRequested: startAfterCautionRibbon,
                    onReviewCautionRibbon: reviewCautionRibbon,
                    onRevealInFinder: revealOutputInFinder,
                    onShowInfo: { infoItem = $0 },
                    onShowLog: { logItem = $0 }
                )
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func revealOutputInFinder() {
        if let dir = queue.outputDirectory {
            NSWorkspace.shared.activateFileViewerSelecting([dir])
            return
        }
        let recent = queue.items
            .compactMap { item -> URL? in
                if case .done = item.status { return item.outputURL }
                return nil
            }
            .last
        if let recent {
            NSWorkspace.shared.activateFileViewerSelecting([recent])
        }
    }

    // MARK: - Output popover

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
        switch ReadyCheckPolicy.decisionForStart(issues: issues, confirmBeforeRun: settings.confirmBeforeRun) {
        case .start:
            queue.start()
        case .showCautionRibbon:
            cautionRibbonIssues = issues
        case .showSheet:
            presentPreflight(issues)
        }
    }

    private func startAfterCautionRibbon() {
        let issues = queue.preflightIssuesForPendingItems()
        cautionRibbonIssues = []
        switch ReadyCheckPolicy.decisionAfterCautionReview(issues: issues, confirmBeforeRun: settings.confirmBeforeRun) {
        case .start:
            queue.start()
        case .showCautionRibbon:
            cautionRibbonIssues = issues
        case .showSheet:
            presentPreflight(issues)
        }
    }

    private func reviewCautionRibbon() {
        let issues = queue.preflightIssuesForPendingItems()
        cautionRibbonIssues = issues
        guard !issues.isEmpty else { return }
        presentPreflight(issues)
    }

    private func presentPreflight(_ issues: [PreflightIssue]) {
        preflightSheet = PreflightSheetPayload(issues: issues)
    }

    private func recordIntake(_ result: IntakeResult) {
        intakeMessage = result.message
    }

    // MARK: - File pickers

    private func pickFiles() {
        let urls = FilePicker.pickFiles()
        if !urls.isEmpty {
            addFiles(urls)
        }
    }

    private func addFiles(_ urls: [URL]) {
        Task {
            let result = await queue.add(urls: urls, defaultActionFor: settings.defaultAction(for:))
            recordIntake(result)
        }
    }

    private func pickOutputDirectory() {
        if let url = FilePicker.pickOutputDirectory() {
            queue.outputDirectory = url
            settings.outputDirectory = url
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
                addFiles(dropped)
            }
        }
        return true
    }

    // MARK: - Status helpers

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

private struct InfoSheet: View {
    let item: FileItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TextOutputSheet(
            title: item.displayName,
            subtitle: "BIOS info readout",
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
            subtitle: "Service log",
            text: item.logOutput ?? "(no log output)",
            done: { dismiss() }
        )
    }
}
