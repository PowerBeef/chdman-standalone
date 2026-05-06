import XCTest
@testable import Hunky

final class DiscAuditTests: XCTestCase {
    private let gameName = "Example Game"
    private let otherGameName = "Other Game"

    func testSwappedTrackReportsWrongTrack() throws {
        let original = baseFiles()
        var sabotaged = original
        sabotaged["Example Game (Track 12).bin"] = original["Example Game (Track 11).bin"]
        let fixture = try makeFixture(files: sabotaged, expectedFiles: original)

        let issues = evaluate(fixture)

        XCTAssertTrue(issues.contains {
            $0.kind == .wrongTrack(expected: 12, found: 11, gameName: gameName)
        })
    }

    func testWrongTrackOnNonPSXReportsWrongTrack() throws {
        let original = baseFiles()
        var sabotaged = original
        sabotaged["Example Game (Track 12).bin"] = original["Example Game (Track 11).bin"]
        let fixture = try makeFixture(
            files: sabotaged,
            expectedFiles: original,
            platformKey: "saturn"
        )

        let issues = evaluate(fixture)

        XCTAssertTrue(issues.contains {
            $0.kind == .wrongTrack(expected: 12, found: 11, gameName: gameName)
        })
    }

    func testDuplicateDifferentFilesReportsIdenticalTracksWithoutRedump() throws {
        let files = [
            "Example Game (Track 11).bin": sectorData(byte: 0x11, sectors: 2),
            "Example Game (Track 12).bin": sectorData(byte: 0x11, sectors: 2),
        ]
        let fixture = try makeFixture(files: files, expectedFiles: files, includeRedumpContext: false)

        let issues = evaluate(fixture, includeStatuses: false)

        XCTAssertTrue(issues.contains {
            $0.kind == .duplicateTracks(first: 11, second: 12)
        })
    }

    func testRepeatedCueFileReferenceReportsSameFile() throws {
        let files = [
            "Example Game (Track 11).bin": sectorData(byte: 0x11, sectors: 2),
        ]
        let cue = """
        FILE "Example Game (Track 11).bin" BINARY
          TRACK 11 AUDIO
            INDEX 01 00:02:00
        FILE "Example Game (Track 11).bin" BINARY
          TRACK 12 AUDIO
            INDEX 01 00:02:00
        """
        let fixture = try makeFixture(cue: cue, files: files, expectedFiles: files, includeRedumpContext: false)

        let issues = evaluate(fixture, includeStatuses: false)

        XCTAssertTrue(issues.contains {
            $0.kind == .sameFileReferenced(
                first: 11,
                second: 12,
                fileName: "Example Game (Track 11).bin"
            )
        })
    }

    func testOneByteEditWithSameSizeReportsCorruption() throws {
        let original = baseFiles()
        var sabotaged = original
        var edited = original["Example Game (Track 12).bin"]!
        edited[0] = 0xff
        sabotaged["Example Game (Track 12).bin"] = edited
        let fixture = try makeFixture(files: sabotaged, expectedFiles: original)

        let issues = evaluate(fixture)

        XCTAssertTrue(issues.contains {
            $0.kind == .trackCorrupted(track: 12, gameName: gameName)
        })
    }

    func testTruncatedTrackReportsWrongSize() throws {
        let original = baseFiles()
        var sabotaged = original
        sabotaged["Example Game (Track 12).bin"] = sectorData(byte: 0x22, sectors: 3)
        let fixture = try makeFixture(files: sabotaged, expectedFiles: original)

        let issues = evaluate(fixture)

        XCTAssertTrue(issues.contains {
            if case .wrongSize(let track, _, _) = $0.kind {
                return track == 12
            }
            return false
        })
    }

    func testWrongGameTrackReportsDifferentGame() throws {
        var original = baseFiles()
        original["Example Game (Track 03).bin"] = sectorData(byte: 0x33, sectors: 6)
        var sabotaged = original
        let otherTrack = RedumpDatabase.Entry(
            gameName: otherGameName,
            romName: "Other Game (Track 12).bin",
            size: UInt64(sectorData(byte: 0xee, sectors: 5).count),
            crc32: CRC32.data(sectorData(byte: 0xee, sectors: 5))
        )
        sabotaged["Example Game (Track 12).bin"] = sectorData(byte: 0xee, sectors: 5)
        let fixture = try makeFixture(
            files: sabotaged,
            expectedFiles: original,
            extraRedumpEntries: [otherTrack]
        )

        let issues = evaluate(fixture)

        XCTAssertTrue(issues.contains {
            $0.kind == .differentGame(
                track: 12,
                foundGame: otherGameName,
                expectedGame: gameName
            )
        })
    }

    func testCueOnlyMutationReportsCueChanged() throws {
        let originalCue = defaultCue(for: baseFiles().keys.sorted())
        let mutatedCue = originalCue.replacingOccurrences(of: "INDEX 01 00:02:00", with: "INDEX 01 00:03:00")
        let fixture = try makeFixture(
            cue: mutatedCue,
            files: baseFiles(),
            expectedFiles: baseFiles(),
            expectedCue: originalCue
        )

        let issues = evaluate(fixture)

        XCTAssertTrue(issues.contains {
            $0.kind == .cueChanged(gameName: gameName)
        })
    }

    func testGDISheetMutationReportsSheetChanged() throws {
        let dir = try makeTemporaryDirectory()
        let originalGDI = """
        1
        1 0 4 2352 track01.bin 0
        """
        let mutatedGDI = """
        1
        1 150 4 2352 track01.bin 0
        """
        let gdiURL = dir.appendingPathComponent("Example Game.gdi")
        try mutatedGDI.write(to: gdiURL, atomically: true, encoding: .utf8)
        let originalData = Data(originalGDI.utf8)
        let context = DiscAudit.RedumpContext(
            platformKey: "dreamcast",
            gameName: gameName,
            trackEntriesByNumber: [:],
            sheetEntries: [
                RedumpDatabase.Entry(
                    platformKey: "dreamcast",
                    gameName: gameName,
                    romName: "Example Game.gdi",
                    size: UInt64(originalData.count),
                    crc32: CRC32.data(originalData)
                )
            ]
        )

        let issues = DiscAudit.evaluate(
            sheetURL: gdiURL,
            references: [],
            fingerprints: [:],
            redumpStatuses: [:],
            sheetFingerprint: FileFingerprint.file(at: gdiURL),
            redumpContext: context
        )

        XCTAssertTrue(issues.contains {
            $0.kind == .cueChanged(gameName: gameName)
        })
    }

    func testGDISheetDoesNotCompareAgainstRedumpCueEntry() throws {
        let dir = try makeTemporaryDirectory()
        let gdi = """
        1
        1 0 4 2352 track01.bin 0
        """
        let gdiURL = dir.appendingPathComponent("Example Game.gdi")
        try gdi.write(to: gdiURL, atomically: true, encoding: .utf8)
        let cueData = Data("""
        FILE "track01.bin" BINARY
          TRACK 01 MODE1/2352
            INDEX 01 00:00:00
        """.utf8)
        let context = DiscAudit.RedumpContext(
            platformKey: "dreamcast",
            gameName: gameName,
            trackEntriesByNumber: [:],
            sheetEntries: [
                RedumpDatabase.Entry(
                    platformKey: "dreamcast",
                    gameName: gameName,
                    romName: "Example Game.cue",
                    size: UInt64(cueData.count),
                    crc32: CRC32.data(cueData)
                )
            ]
        )

        let issues = DiscAudit.evaluate(
            sheetURL: gdiURL,
            references: [],
            fingerprints: [:],
            redumpStatuses: [:],
            sheetFingerprint: FileFingerprint.file(at: gdiURL),
            redumpContext: context
        )

        XCTAssertFalse(issues.contains {
            $0.kind == .cueChanged(gameName: gameName)
        })
    }

    func testFilenameTrackMismatchReportsWarning() throws {
        let files = [
            "Example Game (Track 11).bin": sectorData(byte: 0x11, sectors: 2),
        ]
        let cue = """
        FILE "Example Game (Track 11).bin" BINARY
          TRACK 12 AUDIO
            INDEX 01 00:02:00
        """
        let fixture = try makeFixture(cue: cue, files: files, expectedFiles: files, includeRedumpContext: false)

        let issues = evaluate(fixture, includeStatuses: false)

        XCTAssertTrue(issues.contains {
            $0.kind == .filenameTrackMismatch(
                cueTrack: 12,
                filenameTrack: 11,
                fileName: "Example Game (Track 11).bin"
            )
        })
    }

    func testUnreferencedSiblingTrackReportsWarning() throws {
        let files = [
            "Example Game (Track 11).bin": sectorData(byte: 0x11, sectors: 2),
            "Example Game (Track 12).bin": sectorData(byte: 0x22, sectors: 3),
        ]
        let cue = """
        FILE "Example Game (Track 11).bin" BINARY
          TRACK 11 AUDIO
            INDEX 01 00:02:00
        """
        let fixture = try makeFixture(cue: cue, files: files, expectedFiles: files, includeRedumpContext: false)

        let issues = evaluate(fixture, includeStatuses: false)

        XCTAssertTrue(issues.contains {
            $0.kind == .unreferencedTrack(fileName: "Example Game (Track 12).bin", track: 12)
        })
    }

    func testSectorMisalignedTrackReportsWarning() throws {
        let original = baseFiles()
        var sabotaged = original
        sabotaged["Example Game (Track 12).bin"] = sectorData(byte: 0x22, sectors: 5) + Data([0x99])
        let fixture = try makeFixture(files: sabotaged, expectedFiles: original)

        let issues = evaluate(fixture)

        XCTAssertTrue(issues.contains {
            if case .sectorMisaligned(let track, _, _) = $0.kind {
                return track == 12
            }
            return false
        })
    }

    func testTinyTrackReportsWarning() throws {
        let original = baseFiles()
        var sabotaged = original
        sabotaged["Example Game (Track 12).bin"] = Data([0x22])
        let fixture = try makeFixture(files: sabotaged, expectedFiles: original)

        let issues = evaluate(fixture)

        XCTAssertTrue(issues.contains {
            if case .unexpectedlySmall(let track, _, _) = $0.kind {
                return track == 12
            }
            return false
        })
    }

    func testISOSingleFileAuditDoesNotReportSiblingTrackSlots() throws {
        let dir = try makeTemporaryDirectory()
        let isoURL = dir.appendingPathComponent("Example Game.iso")
        let siblingURL = dir.appendingPathComponent("Example Game (Track 02).bin")
        try sectorData(byte: 0x44, sectors: 4).write(to: isoURL)
        try sectorData(byte: 0x22, sectors: 2).write(to: siblingURL)
        let reference = DiscSheet.Reference(url: isoURL.standardizedFileURL, exists: true, tracks: [])

        let issues = DiscAudit.evaluate(
            sheetURL: isoURL,
            references: [reference],
            fingerprints: [
                reference.url: FileFingerprint.file(at: isoURL)!
            ],
            redumpStatuses: [:],
            sheetFingerprint: nil,
            redumpContext: nil
        )

        XCTAssertFalse(issues.contains {
            if case .unreferencedTrack = $0.kind {
                return true
            }
            return false
        })
    }

    func testDreamcastGDIWithOnlyPSXSizeCollisionDoesNotWarn() throws {
        let dir = try makeTemporaryDirectory()
        let track01 = dir.appendingPathComponent("track01.bin")
        let track02 = dir.appendingPathComponent("track02.raw")
        let track03 = dir.appendingPathComponent("track03.bin")
        try Data(repeating: 0x01, count: 705_600).write(to: track01)
        try Data(repeating: 0x02, count: 1_237_152).write(to: track02)
        try sectorData(byte: 0x03, sectors: 5).write(to: track03)

        let gdi = """
        3
        1 0 4 2352 track01.bin 0
        2 450 0 2352 track02.raw 0
        3 45000 4 2352 track03.bin 0
        """
        let gdiURL = dir.appendingPathComponent("Soul Calibur.gdi")
        try gdi.write(to: gdiURL, atomically: true, encoding: .utf8)
        let references = DiscSheet.references(in: gdiURL)
        let fingerprints = references.reduce(into: [URL: FileFingerprint]()) { partial, ref in
            partial[ref.url] = FileFingerprint.file(at: ref.url)
        }
        let statuses: [URL: RedumpDatabase.Status] = [
            references[0].url: .unknown,
            references[1].url: .sizeMatchedButCRCMismatch(
                platformKey: "psx",
                gameName: "Unrelated PSX Disc",
                romName: "Unrelated PSX Disc (Track 02).bin"
            ),
            references[2].url: .unknown,
        ]

        XCTAssertNil(DiscAudit.inferredGameIdentity(redumpStatuses: statuses))
        let issues = DiscAudit.evaluate(
            sheetURL: gdiURL,
            references: references,
            fingerprints: fingerprints,
            redumpStatuses: statuses,
            sheetFingerprint: FileFingerprint.file(at: gdiURL),
            redumpContext: nil
        )

        XCTAssertTrue(issues.isEmpty)
    }

    func testMissingPlatformDatShowsUnavailableAggregate() throws {
        let dir = try makeTemporaryDirectory()
        let gdiURL = dir.appendingPathComponent("Game.gdi")
        let trackURL = dir.appendingPathComponent("track01.bin")
        try sectorData(byte: 0x01, sectors: 2).write(to: trackURL)
        try """
        1
        1 0 4 2352 track01.bin 0
        """.write(to: gdiURL, atomically: true, encoding: .utf8)
        let item = FileItem(url: gdiURL, kind: .cdImage)

        item.redumpUnavailablePlatform = .dreamcast

        XCTAssertEqual(item.redumpAggregate, .unavailable(platform: .dreamcast))
    }

    func testDreamcastGDIPregapDeltaDoesNotReportWrongSize() throws {
        let fixture = dreamcastPregapFixture(
            sheetExtension: "gdi",
            localTrack: 2,
            localSectors: 526,
            expectedTrack: 2,
            expectedSectors: 676,
            mode: "AUDIO"
        )

        let issues = evaluateSynthetic(fixture)

        XCTAssertFalse(issues.containsWrongSize(track: 2))
    }

    func testDreamcastGDIPregapDeltaNormalizesAggregateToVerified() throws {
        let sheetURL = URL(fileURLWithPath: "/tmp/Example Game.gdi")
        let track1 = syntheticReference(track: 1, name: "track01.bin", mode: "MODE1/2352")
        let track2 = syntheticReference(track: 2, name: "track02.raw", mode: "AUDIO")
        let track3 = syntheticReference(track: 3, name: "track03.bin", mode: "MODE1/2352")
        let entry1 = syntheticEntry(track: 1, sectors: 300, crc32: 0x11111111)
        let entry2 = syntheticEntry(track: 2, sectors: 676, crc32: 0x22222222)
        let entry3 = syntheticEntry(track: 3, sectors: 504_150, crc32: 0x33333333)
        let context = syntheticContext(entries: [entry1, entry2, entry3])
        let references = [track1, track2, track3]
        let statuses: [URL: RedumpDatabase.Status] = [
            track1.url: .verified(candidates: [entry1]),
            track2.url: .unknown,
            track3.url: .verified(candidates: [entry3]),
        ]
        let fingerprints: [URL: FileFingerprint] = [
            track1.url: FileFingerprint(size: entry1.size, crc32: entry1.crc32),
            track2.url: FileFingerprint(size: entry2.size - UInt64(150 * 2352), crc32: 0x99999999),
            track3.url: FileFingerprint(size: entry3.size, crc32: entry3.crc32),
        ]

        let normalized = DiscAudit.normalizedRedumpStatuses(
            sheetURL: sheetURL,
            references: references,
            fingerprints: fingerprints,
            redumpStatuses: statuses,
            redumpContext: context
        )
        let item = FileItem(url: sheetURL, kind: .cdImage)
        item.references = references
        item.redumpStatuses = normalized

        XCTAssertEqual(normalized[track2.url], .verified(candidates: [entry2]))
        XCTAssertEqual(
            item.redumpAggregate,
            .verified(identity: DiscAudit.RedumpIdentity(platformKey: "dreamcast", gameName: gameName))
        )
    }

    func testDreamcastGDIPregapDeltaOffBy149SectorsStillReportsWrongSize() throws {
        let fixture = dreamcastPregapFixture(
            sheetExtension: "gdi",
            localTrack: 2,
            localSectors: 527,
            expectedTrack: 2,
            expectedSectors: 676,
            mode: "AUDIO"
        )

        let issues = evaluateSynthetic(fixture)

        XCTAssertTrue(issues.containsWrongSize(track: 2))
    }

    func testDreamcastGDIPregapDeltaOffBy151SectorsStillReportsWrongSize() throws {
        let fixture = dreamcastPregapFixture(
            sheetExtension: "gdi",
            localTrack: 2,
            localSectors: 525,
            expectedTrack: 2,
            expectedSectors: 676,
            mode: "AUDIO"
        )

        let issues = evaluateSynthetic(fixture)

        XCTAssertTrue(issues.containsWrongSize(track: 2))
    }

    func testDreamcastGDIPregapDeltaOnTrack1StillReportsWrongSize() throws {
        let fixture = dreamcastPregapFixture(
            sheetExtension: "gdi",
            localTrack: 1,
            localSectors: 526,
            expectedTrack: 1,
            expectedSectors: 676,
            mode: "AUDIO"
        )

        let issues = evaluateSynthetic(fixture)

        XCTAssertTrue(issues.containsWrongSize(track: 1))
    }

    func testDreamcastPregapDeltaOnCueStillReportsWrongSize() throws {
        let fixture = dreamcastPregapFixture(
            sheetExtension: "cue",
            localTrack: 2,
            localSectors: 526,
            expectedTrack: 2,
            expectedSectors: 676,
            mode: "AUDIO"
        )

        let issues = evaluateSynthetic(fixture)

        XCTAssertTrue(issues.containsWrongSize(track: 2))
    }

    func testDreamcastGDIExactTrack3MatchHasNoWrongSize() throws {
        let fixture = dreamcastPregapFixture(
            sheetExtension: "gdi",
            localTrack: 3,
            localSectors: 676,
            expectedTrack: 3,
            expectedSectors: 676,
            mode: "MODE1/2352"
        )

        let issues = evaluateSynthetic(fixture)

        XCTAssertFalse(issues.containsWrongSize(track: 3))
    }

    private struct Fixture {
        let cueURL: URL
        let references: [DiscSheet.Reference]
        let fingerprints: [URL: FileFingerprint]
        let statuses: [URL: RedumpDatabase.Status]
        let sheetFingerprint: FileFingerprint?
        let context: DiscAudit.RedumpContext?
    }

    private func makeFixture(
        cue: String? = nil,
        files: [String: Data],
        expectedFiles: [String: Data],
        expectedCue: String? = nil,
        platformKey: String = "psx",
        includeRedumpContext: Bool = true,
        extraRedumpEntries: [RedumpDatabase.Entry] = []
    ) throws -> Fixture {
        let dir = try makeTemporaryDirectory()
        for (name, data) in files {
            try data.write(to: dir.appendingPathComponent(name))
        }

        let cueText = cue ?? defaultCue(for: files.keys.sorted())
        let cueURL = dir.appendingPathComponent("Example Game.cue")
        try cueText.write(to: cueURL, atomically: true, encoding: .utf8)

        let references = DiscSheet.references(in: cueURL)
        let fingerprints = references.reduce(into: [URL: FileFingerprint]()) { partial, ref in
            partial[ref.url] = FileFingerprint.file(at: ref.url)
        }
        let entries = redumpEntries(for: expectedFiles, platformKey: platformKey) + extraRedumpEntries
        let statuses = references.reduce(into: [URL: RedumpDatabase.Status]()) { partial, ref in
            guard let fingerprint = fingerprints[ref.url] else { return }
            partial[ref.url] = RedumpDatabase.status(
                entries: entries,
                crc32: fingerprint.crc32,
                size: fingerprint.size,
                expectedTrackNumber: ref.singleTrackNumber
            )
        }
        let sheetFingerprint = FileFingerprint.file(at: cueURL)
        let context = includeRedumpContext ? redumpContext(
            expectedFiles: expectedFiles,
            expectedCue: expectedCue ?? cueText,
            platformKey: platformKey
        ) : nil

        return Fixture(
            cueURL: cueURL,
            references: references,
            fingerprints: fingerprints,
            statuses: statuses,
            sheetFingerprint: sheetFingerprint,
            context: context
        )
    }

    private func evaluate(_ fixture: Fixture, includeStatuses: Bool = true) -> [DiscAuditIssue] {
        DiscAudit.evaluate(
            sheetURL: fixture.cueURL,
            references: fixture.references,
            fingerprints: fixture.fingerprints,
            redumpStatuses: includeStatuses ? fixture.statuses : [:],
            sheetFingerprint: fixture.sheetFingerprint,
            redumpContext: fixture.context
        )
    }

    private func redumpContext(
        expectedFiles: [String: Data],
        expectedCue: String,
        platformKey: String
    ) -> DiscAudit.RedumpContext {
        var trackEntries: [Int: RedumpDatabase.Entry] = [:]
        for entry in redumpEntries(for: expectedFiles, platformKey: platformKey) {
            if let trackNumber = entry.trackNumber {
                trackEntries[trackNumber] = entry
            }
        }
        let cueData = Data(expectedCue.utf8)
        return DiscAudit.RedumpContext(
            platformKey: platformKey,
            gameName: gameName,
            trackEntriesByNumber: trackEntries,
            sheetEntries: [
                RedumpDatabase.Entry(
                    platformKey: platformKey,
                    gameName: gameName,
                    romName: "Example Game.cue",
                    size: UInt64(cueData.count),
                    crc32: CRC32.data(cueData)
                )
            ]
        )
    }

    private func redumpEntries(
        for files: [String: Data],
        platformKey: String
    ) -> [RedumpDatabase.Entry] {
        files.compactMap { pair in
            let name = pair.key
            let data = pair.value
            guard DiscAudit.filenameTrackNumber(in: URL(fileURLWithPath: name)) != nil else {
                return nil
            }
            return RedumpDatabase.Entry(
                platformKey: platformKey,
                gameName: gameName,
                romName: name,
                size: UInt64(data.count),
                crc32: CRC32.data(data)
            )
        }
    }

    private func baseFiles() -> [String: Data] {
        [
            "Example Game (Track 11).bin": sectorData(byte: 0x11, sectors: 4),
            "Example Game (Track 12).bin": sectorData(byte: 0x22, sectors: 5),
        ]
    }

    private struct SyntheticFixture {
        let sheetURL: URL
        let references: [DiscSheet.Reference]
        let fingerprints: [URL: FileFingerprint]
        let context: DiscAudit.RedumpContext
    }

    private func dreamcastPregapFixture(
        sheetExtension: String,
        localTrack: Int,
        localSectors: Int,
        expectedTrack: Int,
        expectedSectors: Int,
        mode: String
    ) -> SyntheticFixture {
        let sheetURL = URL(fileURLWithPath: "/tmp/Example Game.\(sheetExtension)")
        let fileExtension = mode.uppercased() == "AUDIO" ? "raw" : "bin"
        let reference = syntheticReference(
            track: localTrack,
            name: "track\(String(format: "%02d", localTrack)).\(fileExtension)",
            mode: mode
        )
        let entry = syntheticEntry(
            track: expectedTrack,
            sectors: expectedSectors,
            crc32: 0x12345678
        )
        return SyntheticFixture(
            sheetURL: sheetURL,
            references: [reference],
            fingerprints: [
                reference.url: FileFingerprint(
                    size: UInt64(localSectors * 2352),
                    crc32: 0x87654321
                )
            ],
            context: syntheticContext(entries: [entry])
        )
    }

    private func syntheticReference(track: Int, name: String, mode: String) -> DiscSheet.Reference {
        DiscSheet.Reference(
            url: URL(fileURLWithPath: "/tmp/\(name)").standardizedFileURL,
            exists: true,
            tracks: [
                DiscSheet.Track(number: track, mode: mode)
            ]
        )
    }

    private func syntheticEntry(track: Int, sectors: Int, crc32: UInt32) -> RedumpDatabase.Entry {
        RedumpDatabase.Entry(
            platformKey: "dreamcast",
            gameName: gameName,
            romName: "Example Game (Track \(String(format: "%02d", track))).bin",
            size: UInt64(sectors * 2352),
            crc32: crc32
        )
    }

    private func syntheticContext(entries: [RedumpDatabase.Entry]) -> DiscAudit.RedumpContext {
        var trackEntries: [Int: RedumpDatabase.Entry] = [:]
        for entry in entries {
            if let trackNumber = entry.trackNumber {
                trackEntries[trackNumber] = entry
            }
        }
        return DiscAudit.RedumpContext(
            platformKey: "dreamcast",
            gameName: gameName,
            trackEntriesByNumber: trackEntries,
            sheetEntries: []
        )
    }

    private func evaluateSynthetic(_ fixture: SyntheticFixture) -> [DiscAuditIssue] {
        DiscAudit.evaluate(
            sheetURL: fixture.sheetURL,
            references: fixture.references,
            fingerprints: fixture.fingerprints,
            redumpStatuses: [:],
            sheetFingerprint: nil,
            redumpContext: fixture.context,
            siblingTrackFiles: []
        )
    }

    private func defaultCue(for fileNames: [String]) -> String {
        fileNames.map { name in
            let track = DiscAudit.filenameTrackNumber(in: URL(fileURLWithPath: name)) ?? 1
            return """
            FILE "\(name)" BINARY
              TRACK \(String(format: "%02d", track)) AUDIO
                INDEX 01 00:02:00
            """
        }
        .joined(separator: "\n")
    }

    private func sectorData(byte: UInt8, sectors: Int) -> Data {
        Data(repeating: byte, count: sectors * 2352)
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

private extension Array where Element == DiscAuditIssue {
    func containsWrongSize(track: Int) -> Bool {
        contains {
            if case .wrongSize(let issueTrack, _, _) = $0.kind {
                return issueTrack == track
            }
            return false
        }
    }
}
