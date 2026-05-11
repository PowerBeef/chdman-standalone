import XCTest
@testable import Hunky

@MainActor
final class QueueControllerTests: XCTestCase {
    func testAddReportsAddedDuplicatesUnsupportedAndEmptyFolders() async throws {
        let dir = try makeTemporaryDirectory()
        let chdURL = dir.appendingPathComponent("Game.chd")
        let unsupportedURL = dir.appendingPathComponent("notes.txt")
        let emptyFolderURL = dir.appendingPathComponent("Empty", isDirectory: true)
        try Data([0x01]).write(to: chdURL)
        try Data([0x02]).write(to: unsupportedURL)
        try FileManager.default.createDirectory(at: emptyFolderURL, withIntermediateDirectories: true)
        let queue = QueueController()

        let result = await queue.add(urls: [chdURL, chdURL, unsupportedURL, emptyFolderURL])

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.duplicates, 1)
        XCTAssertEqual(result.unsupported, 1)
        XCTAssertEqual(result.emptyFolders, 1)
        XCTAssertEqual(queue.items.map(\.url), [chdURL.standardizedFileURL])
        XCTAssertEqual(result.message, "1 added, 1 duplicate skipped, 1 unsupported file skipped, 1 folder had no supported files")
    }

    func testPreflightReportsMissingReferencesAndAuditWarnings() throws {
        let dir = try makeTemporaryDirectory()
        let cueURL = dir.appendingPathComponent("Game.cue")
        let cue = """
        FILE "Missing (Track 01).bin" BINARY
          TRACK 01 MODE2/2352
            INDEX 01 00:00:00
        """
        try cue.write(to: cueURL, atomically: true, encoding: .utf8)
        let item = FileItem(url: cueURL, kind: .cdImage)
        item.redumpInProgress = false
        item.auditIssues = [
            DiscAuditIssue(kind: .filenameTrackMismatch(
                cueTrack: 1,
                filenameTrack: 2,
                fileName: "Game (Track 02).bin"
            ))
        ]
        let queue = QueueController()
        queue.items = [item]

        let issues = queue.preflightIssuesForPendingItems()

        XCTAssertEqual(issues.count, 2)
        XCTAssertEqual(issues.map(\.severity), [.critical, .caution])
        XCTAssertTrue(issues.contains { $0.title == "Missing reference file" })
        XCTAssertTrue(issues.contains { $0.title == "Cue track number does not match filename" })
    }

    func testPreflightIncludesAuditInProgress() throws {
        let dir = try makeTemporaryDirectory()
        let isoURL = dir.appendingPathComponent("Game.iso")
        try Data(repeating: 0x42, count: 2048).write(to: isoURL)
        let item = FileItem(url: isoURL, kind: .cdImage)
        item.redumpInProgress = true
        let queue = QueueController()
        queue.items = [item]

        let issues = queue.preflightIssuesForPendingItems()

        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.severity, .caution)
        XCTAssertEqual(issues.first?.title, "Disc audit still running")
    }

    func testRetryClearsFailedStateOutputAndLogs() throws {
        let dir = try makeTemporaryDirectory()
        let chdURL = dir.appendingPathComponent("Game.chd")
        let outputURL = dir.appendingPathComponent("Game.cue")
        try Data([0x01]).write(to: chdURL)
        let item = FileItem(url: chdURL, kind: .chd)
        item.status = .failed(message: "bad input")
        item.outputURL = outputURL
        item.infoOutput = "info"
        item.logOutput = "stderr"
        let queue = QueueController()
        queue.items = [item]

        queue.retry(item)

        guard case .idle = item.status else {
            return XCTFail("Expected retry to reset status to idle")
        }
        XCTAssertNil(item.outputURL)
        XCTAssertNil(item.infoOutput)
        XCTAssertNil(item.logOutput)
    }

    func testRunSummaryBreaksDownSuccessfulActions() {
        let now = Date()
        let summary = RunSummary(
            total: 4,
            succeeded: 4,
            created: 1,
            extracted: 1,
            inspected: 1,
            verified: 1,
            failed: 0,
            cancelled: 0,
            startedAt: now,
            endedAt: now
        )

        XCTAssertEqual(summary.successBreakdown, "1 created, 1 extracted, 1 inspected, 1 verified")
        XCTAssertEqual(summary.message, "1 created, 1 extracted, 1 inspected, 1 verified")
    }

    func testRunningQueueKeepsInitialRunSetAndIgnoresRemoval() async throws {
        let dir = try makeTemporaryDirectory()
        let firstURL = dir.appendingPathComponent("First.iso")
        let secondURL = dir.appendingPathComponent("Second.iso")
        let lateURL = dir.appendingPathComponent("Late.iso")
        try Data([0x01]).write(to: firstURL)
        try Data([0x02]).write(to: secondURL)
        try Data([0x03]).write(to: lateURL)
        let gate = TestGate()
        let runner = FakeChdmanRunner(firstRunGate: gate)
        let queue = QueueController(runner: runner)
        _ = await queue.add(urls: [firstURL, secondURL])

        queue.start()
        try await waitForRunCount(1, runner: runner)
        queue.remove(queue.items[1])
        _ = await queue.add(urls: [lateURL])
        XCTAssertEqual(queue.items.map(\.url), [
            firstURL.standardizedFileURL,
            secondURL.standardizedFileURL,
            lateURL.standardizedFileURL,
        ])

        await gate.open()
        try await waitUntilFinished(queue)

        let history = await runner.history()
        XCTAssertEqual(history.count, 2)
        XCTAssertTrue(history.flatMap { $0 }.contains(firstURL.path))
        XCTAssertTrue(history.flatMap { $0 }.contains(secondURL.path))
        XCTAssertFalse(history.flatMap { $0 }.contains(lateURL.path))
    }

    func testOutputCollisionUsesReservedSuffixWithoutOverwritingExistingFile() async throws {
        let dir = try makeTemporaryDirectory()
        let isoURL = dir.appendingPathComponent("Game.iso")
        let existingCHD = dir.appendingPathComponent("Game.chd")
        try Data([0x01]).write(to: isoURL)
        try Data("existing".utf8).write(to: existingCHD)
        let runner = FakeChdmanRunner()
        let queue = QueueController(runner: runner)
        _ = await queue.add(urls: [isoURL])

        queue.start()
        try await waitUntilFinished(queue)

        XCTAssertEqual(queue.items.first?.outputURL?.lastPathComponent, "Game (2).chd")
        XCTAssertEqual(try Data(contentsOf: existingCHD), Data("existing".utf8))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("Game (2).chd")), FakeChdmanRunner.outputData)
    }

    func testCancellationRemovesOnlyReservedOutput() async throws {
        let dir = try makeTemporaryDirectory()
        let isoURL = dir.appendingPathComponent("Game.iso")
        let outputURL = dir.appendingPathComponent("Game.chd")
        try Data([0x01]).write(to: isoURL)
        let runner = FakeChdmanRunner(mode: .waitForCancel)
        let queue = QueueController(runner: runner)
        _ = await queue.add(urls: [isoURL])

        queue.start()
        try await waitForRunCount(1, runner: runner)
        queue.cancel()
        try await waitUntilFinished(queue)

        guard case .cancelled = queue.items.first?.status else {
            return XCTFail("Expected item to be cancelled")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testUnwritableOutputFolderFailsBeforeLaunchingRunner() async throws {
        let inputDir = try makeTemporaryDirectory()
        let outputDir = try makeTemporaryDirectory()
        let isoURL = inputDir.appendingPathComponent("Game.iso")
        try Data([0x01]).write(to: isoURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: outputDir.path)
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputDir.path)
        }
        try XCTSkipIf(FileManager.default.isWritableFile(atPath: outputDir.path), "Filesystem still reports the chmodded directory writable.")
        let runner = FakeChdmanRunner()
        let queue = QueueController(runner: runner)
        queue.outputDirectory = outputDir
        _ = await queue.add(urls: [isoURL])

        queue.start()
        try await waitUntilFinished(queue)

        guard case .failed(let message) = queue.items.first?.status else {
            return XCTFail("Expected item to fail before process launch")
        }
        XCTAssertTrue(message.contains("not writable"))
        let history = await runner.history()
        XCTAssertEqual(history.count, 0)
    }

    func testSettingsDefaultActionIsAppliedDuringIntake() async throws {
        let defaults = try makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.defaultChdAction = .verify
        let dir = try makeTemporaryDirectory()
        let chdURL = dir.appendingPathComponent("Game.chd")
        try Data([0x01]).write(to: chdURL)
        let queue = QueueController()

        _ = await queue.add(urls: [chdURL], defaultActionFor: settings.defaultAction(for:))

        XCTAssertEqual(queue.items.first?.action, .verify)
    }

    func testSettingsDefaultActionFallsBackWhenStoredActionIsInvalidForKind() throws {
        let defaults = try makeDefaults()
        defaults.set(Action.createCD.rawValue, forKey: "com.powerbeef.Hunky.settings.defaultChdAction")
        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.defaultAction(for: .chd), .extractCD)
    }

    func testCancelTokenInvokesLateInstalledHandler() {
        let token = CancelToken()
        token.cancel()
        var called = false

        token.setOnCancel {
            called = true
        }

        XCTAssertTrue(called)
    }

    func testCancelTokenClearPreventsCallback() {
        let token = CancelToken()
        var called = false
        token.setOnCancel {
            called = true
        }
        token.clearOnCancel()

        token.cancel()

        XCTAssertFalse(called)
    }

    func testReadyCheckPolicyHonorsConfirmBeforeRunSetting() {
        let caution = makeIssue(severity: .caution)
        let critical = makeIssue(severity: .critical)

        XCTAssertEqual(ReadyCheckPolicy.decisionForStart(issues: [], confirmBeforeRun: false), .start)
        XCTAssertEqual(ReadyCheckPolicy.decisionForStart(issues: [], confirmBeforeRun: true), .showSheet)
        XCTAssertEqual(ReadyCheckPolicy.decisionForStart(issues: [caution], confirmBeforeRun: false), .showCautionRibbon)
        XCTAssertEqual(ReadyCheckPolicy.decisionForStart(issues: [caution], confirmBeforeRun: true), .showSheet)
        XCTAssertEqual(ReadyCheckPolicy.decisionForStart(issues: [critical], confirmBeforeRun: false), .showSheet)
    }

    func testReadyCheckPolicyRechecksStaleCautionRibbonBeforeStartAnyway() {
        let caution = makeIssue(severity: .caution)
        let critical = makeIssue(severity: .critical)

        XCTAssertEqual(ReadyCheckPolicy.decisionAfterCautionReview(issues: [caution], confirmBeforeRun: false), .start)
        XCTAssertEqual(ReadyCheckPolicy.decisionAfterCautionReview(issues: [caution], confirmBeforeRun: true), .showSheet)
        XCTAssertEqual(ReadyCheckPolicy.decisionAfterCautionReview(issues: [critical], confirmBeforeRun: false), .showSheet)
    }

    func testReadyCheckCopyCountsCriticalAndCautionIssuesConsistently() {
        let itemID = UUID()
        let copy = ReadyCheckCopy(issues: [
            makeIssue(itemID: itemID, severity: .critical, title: "Missing reference"),
            makeIssue(itemID: itemID, severity: .critical, title: "Output path unavailable"),
            makeIssue(severity: .caution, title: "Audit still running"),
        ])

        XCTAssertEqual(copy.criticalCount, 2)
        XCTAssertEqual(copy.criticalItemCount, 1)
        XCTAssertEqual(copy.cautionCount, 1)
        XCTAssertEqual(copy.headlineText, "1 slot needs attention")
        XCTAssertTrue(copy.paragraphText.contains("2 critical issues across 1 slot"))
        XCTAssertTrue(copy.paragraphText.contains("1 caution also needs review"))
        XCTAssertEqual(copy.confirmButtonTitle, "Start anyway")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "HunkyTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Could not create isolated UserDefaults suite.")
        }
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    private func makeIssue(
        itemID: UUID = UUID(),
        severity: RiskSeverity,
        title: String = "Issue"
    ) -> PreflightIssue {
        PreflightIssue(
            itemID: itemID,
            fileName: "Game.cue",
            severity: severity,
            title: title,
            detail: title
        )
    }

    private func waitForRunCount(_ count: Int, runner: FakeChdmanRunner) async throws {
        for _ in 0..<200 {
            if await runner.history().count >= count { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for \(count) fake runner call(s).")
    }

    private func waitUntilFinished(_ queue: QueueController) async throws {
        for _ in 0..<300 {
            if !queue.isRunning { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for queue to finish.")
    }
}

private actor TestGate {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private actor FakeChdmanRunner: ChdmanRunning {
    enum Mode: Sendable {
        case success
        case waitForCancel
    }

    static let outputData = Data("fake chdman output".utf8)

    private let mode: Mode
    private let firstRunGate: TestGate?
    private var argsHistory: [[String]] = []

    init(mode: Mode = .success, firstRunGate: TestGate? = nil) {
        self.mode = mode
        self.firstRunGate = firstRunGate
    }

    func history() -> [[String]] {
        argsHistory
    }

    func run(
        args: [String],
        onProgress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancelToken
    ) async throws -> ChdmanResult {
        argsHistory.append(args)
        let runNumber = argsHistory.count
        if runNumber == 1, let firstRunGate {
            await firstRunGate.wait()
        }

        try writeOutputs(from: args)
        onProgress(1)

        switch mode {
        case .success:
            return ChdmanResult(stdout: "", stderr: "")
        case .waitForCancel:
            while !cancelToken.isCancelled {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            throw ChdmanError.nonZeroExit(code: 15, stderr: "cancelled")
        }
    }

    private func writeOutputs(from args: [String]) throws {
        if let output = value(after: "-o", in: args) {
            try Self.outputData.write(to: URL(fileURLWithPath: output))
        }
        if let outputBin = value(after: "-ob", in: args) {
            try Self.outputData.write(to: URL(fileURLWithPath: outputBin))
        }
    }

    private func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag),
              args.indices.contains(args.index(after: index)) else { return nil }
        return args[args.index(after: index)]
    }
}
