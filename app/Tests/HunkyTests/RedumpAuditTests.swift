import XCTest
@testable import Hunky

final class RedumpAuditTests: XCTestCase {
    private let track11 = RedumpDatabase.Entry(
        gameName: "Twisted Metal 2 (USA)",
        romName: "Twisted Metal 2 (USA) (Track 11).bin",
        size: 10_388_784,
        crc32: 0xa082_edae
    )
    private let track12 = RedumpDatabase.Entry(
        gameName: "Twisted Metal 2 (USA)",
        romName: "Twisted Metal 2 (USA) (Track 12).bin",
        size: 32_010_720,
        crc32: 0xbc74_3322
    )

    func testCorrectTrackVerifies() {
        let status = RedumpDatabase.status(
            entries: [track11, track12],
            crc32: 0xbc74_3322,
            size: 32_010_720,
            expectedTrackNumber: 12
        )

        guard case .verified(let candidates) = status else {
            return XCTFail("Expected verified, got \(status)")
        }
        XCTAssertEqual(candidates.map(\.trackNumber), [12])
    }

    func testTrackBytesMatchingAnotherSlotReportWrongTrack() {
        let status = RedumpDatabase.status(
            entries: [track11, track12],
            crc32: 0xa082_edae,
            size: 10_388_784,
            expectedTrackNumber: 12
        )

        XCTAssertEqual(
            status,
            .wrongTrack(expected: 12, found: 11, gameName: "Twisted Metal 2 (USA)")
        )
    }

    func testSizeMatchWithDifferentCRCReportsCorruption() {
        let status = RedumpDatabase.status(
            entries: [track12],
            crc32: 0xdead_beef,
            size: 32_010_720,
            expectedTrackNumber: 12
        )

        XCTAssertEqual(
            status,
            .sizeMatchedButCRCMismatch(
                gameName: "Twisted Metal 2 (USA)",
                romName: "Twisted Metal 2 (USA) (Track 12).bin"
            )
        )
    }

    func testUnknownHomebrewRemainsNonBlocking() {
        let status = RedumpDatabase.status(
            entries: [track11, track12],
            crc32: 0x1234_5678,
            size: 123_456,
            expectedTrackNumber: 12
        )

        XCTAssertEqual(status, .unknown)
    }

    func testDuplicateCueTrackFingerprintsAreReported() {
        let firstURL = URL(fileURLWithPath: "/tmp/Track 11.bin")
        let secondURL = URL(fileURLWithPath: "/tmp/Track 12.bin")
        let references = [
            CueSheet.Reference(
                url: firstURL,
                exists: true,
                tracks: [.init(number: 11, mode: "AUDIO")]
            ),
            CueSheet.Reference(
                url: secondURL,
                exists: true,
                tracks: [.init(number: 12, mode: "AUDIO")]
            ),
        ]
        let fingerprint = FileFingerprint(size: 10_388_784, crc32: 0xa082_edae)

        let duplicate = FileItem.duplicateTrackIssue(
            references: references,
            fingerprints: [
                firstURL: fingerprint,
                secondURL: fingerprint,
            ]
        )

        XCTAssertEqual(duplicate?.first, 11)
        XCTAssertEqual(duplicate?.second, 12)
    }
}
