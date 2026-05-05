import XCTest
@testable import Hunky

final class CueSheetTests: XCTestCase {
    func testReferencesIncludeCueTrackNumbers() throws {
        let dir = try makeTemporaryDirectory()
        let track01 = dir.appendingPathComponent("Game (Track 01).bin")
        let track02 = dir.appendingPathComponent("Game (Track 02).bin")
        _ = FileManager.default.createFile(atPath: track01.path, contents: Data())
        _ = FileManager.default.createFile(atPath: track02.path, contents: Data())

        let cue = """
        FILE "Game (Track 01).bin" BINARY
          TRACK 01 MODE2/2352
            INDEX 01 00:00:00
        FILE "Game (Track 02).bin" BINARY
          TRACK 02 AUDIO
            INDEX 01 00:02:00
        """
        let cueURL = dir.appendingPathComponent("Game.cue")
        try cue.write(to: cueURL, atomically: true, encoding: .utf8)

        let refs = CueSheet.references(in: cueURL)

        XCTAssertEqual(refs.count, 2)
        XCTAssertEqual(refs[0].tracks, [.init(number: 1, mode: "MODE2/2352")])
        XCTAssertEqual(refs[1].tracks, [.init(number: 2, mode: "AUDIO")])
        XCTAssertEqual(refs[0].singleTrackNumber, 1)
        XCTAssertTrue(refs.allSatisfy(\.exists))
    }

    func testSingleFileWithMultipleTracksSkipsStrictSlotMatching() throws {
        let dir = try makeTemporaryDirectory()
        let image = dir.appendingPathComponent("Game.bin")
        _ = FileManager.default.createFile(atPath: image.path, contents: Data())

        let cue = """
        FILE "Game.bin" BINARY
          TRACK 01 MODE2/2352
            INDEX 01 00:00:00
          TRACK 02 AUDIO
            INDEX 01 05:00:00
        """
        let cueURL = dir.appendingPathComponent("Game.cue")
        try cue.write(to: cueURL, atomically: true, encoding: .utf8)

        let refs = CueSheet.references(in: cueURL)

        XCTAssertEqual(refs.count, 1)
        XCTAssertEqual(refs[0].tracks.map(\.number), [1, 2])
        XCTAssertNil(refs[0].singleTrackNumber)
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
