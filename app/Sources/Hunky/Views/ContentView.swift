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
    @State private var searchText = ""

    var body: some View {
        ZStack(alignment: .top) {
            HunkyWindowBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                workbench

                footerBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if isWindowDropTargeted {
                WindowDropOverlay()
            }
        }
        .background(HunkyTheme.Surface.base)
        .frame(minWidth: HunkyLayout.windowMinWidth, minHeight: HunkyLayout.windowMinHeight, alignment: .top)
        .onDrop(of: [.fileURL], isTargeted: $isWindowDropTargeted, perform: handleWindowDrop)
        .toolbar { toolbarContent }
        .containerBackground(for: .window) {
            HunkyWindowBackdrop()
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
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
    // Native macOS unified toolbar. The reference keeps queue controls and
    // search in chrome, while the content region stays a flat split surface.

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            Button {
                pickFiles()
            } label: {
                Image(systemName: "plus")
            }
            .help("Add files or folders (Command-O)")
            .accessibilityLabel("Add files or folders")

            runToolbarControl

            Menu {
                overflowMenuItems
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuIndicator(.hidden)
            .help("More")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            ToolbarFilterSearchGroup(text: $searchText) {
                Button("Show All") {
                    searchText = ""
                }
                .disabled(searchText.isEmpty)
                Button("Retry Failed") { queue.retryFailed() }
                    .disabled(!commandActions.canRetryFailed)
                Button("Clear Finished") { queue.clear() }
                    .disabled(!commandActions.canClearFinished)
            }
        }
    }

    @ViewBuilder
    private var runToolbarControl: some View {
        if queue.isRunning {
            Button {
                queue.cancel()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .keyboardShortcut(".", modifiers: [.command])
            .help("Stop running queue (Command-.)")
            .accessibilityLabel("Stop queue")
        } else {
            if queue.pendingCount == 0 {
                Button {
                    startRequested()
                } label: {
                    Image(systemName: "play.fill")
                }
                .disabled(true)
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Run queue (Command-Return)")
                .accessibilityLabel("Run queue")
            } else {
                Button {
                    startRequested()
                } label: {
                    Label("Run Queue", systemImage: "play.fill")
                }
                .buttonStyle(.glassProminent)
                .tint(HunkyTheme.Accent.base)
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Run queue (Command-Return)")
                .accessibilityLabel("Run queue")
            }
        }
    }

    private var footerBar: some View {
        ZStack {
            Rectangle()
                .fill(HunkyTheme.Hairline.base.opacity(0.52))
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .top)

            Text(footerStatusText)
                .font(HunkyType.label)
                .foregroundStyle(HunkyTheme.Ink.tertiary)
                .lineLimit(1)
        }
        .frame(height: 30)
        .background(HunkyTheme.Surface.footer.opacity(0.12))
    }

    private var footerStatusText: String {
        if let summary = queue.lastRunSummary, summary.hasWork {
            return summary.message
        }
        return "\(queue.items.count) item\(queue.items.count == 1 ? "" : "s")"
    }

    // MARK: - Workbench shell

    private var workbench: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                DiscBayPanel(
                    queue: queue,
                    intakeMessage: intakeMessage,
                    onPickOutputDirectory: pickOutputDirectory,
                    onAddFiles: addFiles
                )
                .frame(width: HunkyLayout.sidebarWidth)
                .frame(maxHeight: .infinity)

                QueueDeckPanel(
                    queue: queue,
                    searchText: $searchText,
                    cautionRibbonIssues: $cautionRibbonIssues,
                    showPlatformBadges: settings.showPlatformBadges,
                    onStartRequested: startRequested,
                    onStartAnywayRequested: startAfterCautionRibbon,
                    onReviewCautionRibbon: reviewCautionRibbon,
                    onRevealInFinder: revealOutputInFinder,
                    onShowInfo: { infoItem = $0 },
                    onShowLog: { logItem = $0 }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                HunkyWindowBackdrop()
            }
            .glassEffect(.regular.tint(HunkyTheme.Glass.panelDeepTint), in: Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            subtitle: "Disc information",
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
