import XCTest
@testable import Hunky

@MainActor
final class QueueControllerTests: XCTestCase {
    func testAddReportsAddedDuplicatesUnsupportedAndEmptyFolders() throws {
        let dir = try makeTemporaryDirectory()
        let chdURL = dir.appendingPathComponent("Game.chd")
        let unsupportedURL = dir.appendingPathComponent("notes.txt")
        let emptyFolderURL = dir.appendingPathComponent("Empty", isDirectory: true)
        try Data([0x01]).write(to: chdURL)
        try Data([0x02]).write(to: unsupportedURL)
        try FileManager.default.createDirectory(at: emptyFolderURL, withIntermediateDirectories: true)
        let queue = QueueController()

        let result = queue.add(urls: [chdURL, chdURL, unsupportedURL, emptyFolderURL])

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

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
