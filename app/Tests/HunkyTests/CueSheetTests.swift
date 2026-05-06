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

        let refs = DiscSheet.references(in: cueURL)

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

        let refs = DiscSheet.references(in: cueURL)

        XCTAssertEqual(refs.count, 1)
        XCTAssertEqual(refs[0].tracks.map(\.number), [1, 2])
        XCTAssertNil(refs[0].singleTrackNumber)
    }

    func testRepeatedFileReferenceRetainsDirectiveCount() throws {
        let dir = try makeTemporaryDirectory()
        let image = dir.appendingPathComponent("Game (Track 11).bin")
        _ = FileManager.default.createFile(atPath: image.path, contents: Data())

        let cue = """
        FILE "Game (Track 11).bin" BINARY
          TRACK 11 AUDIO
            INDEX 01 00:02:00
        FILE "Game (Track 11).bin" BINARY
          TRACK 12 AUDIO
            INDEX 01 00:02:00
        """
        let cueURL = dir.appendingPathComponent("Game.cue")
        try cue.write(to: cueURL, atomically: true, encoding: .utf8)

        let refs = DiscSheet.references(in: cueURL)

        XCTAssertEqual(refs.count, 1)
        XCTAssertEqual(refs[0].tracks.map(\.number), [11, 12])
        XCTAssertEqual(refs[0].fileDirectiveCount, 2)
    }

    func testGDIReferencesIncludeTrackNumbers() throws {
        let dir = try makeTemporaryDirectory()
        let track01 = dir.appendingPathComponent("track01.bin")
        let track02 = dir.appendingPathComponent("track02.raw")
        let track03 = dir.appendingPathComponent("track 03.bin")
        _ = FileManager.default.createFile(atPath: track01.path, contents: Data())
        _ = FileManager.default.createFile(atPath: track02.path, contents: Data())
        _ = FileManager.default.createFile(atPath: track03.path, contents: Data())

        let gdi = """
        3
        1 0 4 2352 track01.bin 0
        2 45000 0 2352 track02.raw 0
        3 549150 4 2352 "track 03.bin" 0
        """
        let gdiURL = dir.appendingPathComponent("Game.gdi")
        try gdi.write(to: gdiURL, atomically: true, encoding: .utf8)

        let refs = DiscSheet.references(in: gdiURL)

        XCTAssertEqual(refs.count, 3)
        XCTAssertEqual(refs[0].tracks, [.init(number: 1, mode: "MODE1/2352")])
        XCTAssertEqual(refs[1].tracks, [.init(number: 2, mode: "AUDIO")])
        XCTAssertEqual(refs[2].tracks, [.init(number: 3, mode: "MODE1/2352")])
        XCTAssertTrue(refs.allSatisfy(\.exists))
    }

    func testISOFileItemUsesSelfAsSingleReference() throws {
        let dir = try makeTemporaryDirectory()
        let isoURL = dir.appendingPathComponent("Game.iso")
        try Data(repeating: 0x42, count: 2048).write(to: isoURL)

        let item = FileItem(url: isoURL, kind: .cdImage)

        XCTAssertEqual(item.references.count, 1)
        XCTAssertEqual(item.references[0].url, isoURL.standardizedFileURL)
        XCTAssertNil(item.references[0].singleTrackNumber)
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
