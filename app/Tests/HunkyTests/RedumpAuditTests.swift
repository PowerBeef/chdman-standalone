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
            .wrongTrack(
                platformKey: "psx",
                expected: 12,
                found: 11,
                gameName: "Twisted Metal 2 (USA)"
            )
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
                platformKey: "psx",
                gameName: "Twisted Metal 2 (USA)",
                romName: "Twisted Metal 2 (USA) (Track 12).bin"
            )
        )
    }

    func testSizeOnlyMismatchDoesNotInferGameIdentity() {
        let status = RedumpDatabase.Status.sizeMatchedButCRCMismatch(
            platformKey: "psx",
            gameName: "Unrelated PSX Disc",
            romName: "Unrelated PSX Disc (Track 02).bin"
        )

        XCTAssertNil(DiscAudit.inferredGameIdentity(redumpStatuses: [
            URL(fileURLWithPath: "/tmp/track02.raw"): status
        ]))
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
            DiscSheet.Reference(
                url: firstURL,
                exists: true,
                tracks: [.init(number: 11, mode: "AUDIO")]
            ),
            DiscSheet.Reference(
                url: secondURL,
                exists: true,
                tracks: [.init(number: 12, mode: "AUDIO")]
            ),
        ]
        let fingerprint = FileFingerprint(size: 10_388_784, crc32: 0xa082_edae)

        let duplicate = DiscAudit.duplicateTrackIssue(
            references: references,
            fingerprints: [
                firstURL: fingerprint,
                secondURL: fingerprint,
            ]
        )

        XCTAssertEqual(duplicate?.first, 11)
        XCTAssertEqual(duplicate?.second, 12)
    }

    func testNonPSXEntriesVerifyWithPlatformKey() {
        let saturnTrack = RedumpDatabase.Entry(
            platformKey: "saturn",
            gameName: "Saturn Game",
            romName: "Saturn Game (Track 01).bin",
            size: 2352,
            crc32: 0xabcd_1234
        )

        let status = RedumpDatabase.status(
            entries: [saturnTrack],
            crc32: 0xabcd_1234,
            size: 2352,
            expectedTrackNumber: 1
        )

        guard case .verified(let candidates) = status else {
            return XCTFail("Expected verified, got \(status)")
        }
        XCTAssertEqual(candidates.first?.platformKey, "saturn")
    }

    func testConsensusPrefersPlatformWithMoreMatchedReferences() {
        let sharedURL = URL(fileURLWithPath: "/tmp/shared.bin")
        let saturnURL = URL(fileURLWithPath: "/tmp/saturn-only.bin")
        let psxShared = RedumpDatabase.Entry(
            platformKey: "psx",
            gameName: "Shared Disc",
            romName: "Shared Disc (Track 01).bin",
            size: 2352,
            crc32: 0x1111_1111
        )
        let saturnShared = RedumpDatabase.Entry(
            platformKey: "saturn",
            gameName: "Saturn Disc",
            romName: "Saturn Disc (Track 01).bin",
            size: 2352,
            crc32: 0x1111_1111
        )
        let saturnOnly = RedumpDatabase.Entry(
            platformKey: "saturn",
            gameName: "Saturn Disc",
            romName: "Saturn Disc (Track 02).bin",
            size: 2352,
            crc32: 0x2222_2222
        )

        let identity = DiscAudit.inferredGameIdentity(redumpStatuses: [
            sharedURL: .verified(candidates: [psxShared, saturnShared]),
            saturnURL: .verified(candidates: [saturnOnly]),
        ])

        XCTAssertEqual(identity, .init(platformKey: "saturn", gameName: "Saturn Disc"))
    }
}
