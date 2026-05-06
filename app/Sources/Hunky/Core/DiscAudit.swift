import Foundation

enum DiscAudit {
    struct RedumpIdentity: Equatable, Hashable, Sendable {
        let platformKey: String
        let gameName: String
    }

    struct RedumpContext: Sendable {
        let platformKey: String
        let gameName: String
        let trackEntriesByNumber: [Int: RedumpDatabase.Entry]
        let sheetEntries: [RedumpDatabase.Entry]
    }

    static func inferredGameName(redumpStatuses: [URL: RedumpDatabase.Status]) -> String? {
        inferredGameIdentity(redumpStatuses: redumpStatuses)?.gameName
    }

    static func inferredGameIdentity(redumpStatuses: [URL: RedumpDatabase.Status]) -> RedumpIdentity? {
        var strongCounts: [String: Int] = [:]

        for status in redumpStatuses.values {
            switch status {
            case .verified(let candidates):
                for identity in Set(candidates.map(\.redumpIdentity)) {
                    strongCounts[identity.countKey, default: 0] += 1
                }
            case .wrongTrack(let platformKey, _, _, let gameName):
                strongCounts[Self.countKey(platformKey: platformKey, gameName: gameName), default: 0] += 1
            case .sizeMatchedButCRCMismatch:
                break
            case .unknown:
                break
            }
        }

        return identity(from: uniqueBest(in: strongCounts))
    }

    static func evaluate(
        sheetURL: URL,
        references: [DiscSheet.Reference],
        fingerprints: [URL: FileFingerprint],
        redumpStatuses: [URL: RedumpDatabase.Status],
        sheetFingerprint: FileFingerprint?,
        redumpContext: RedumpContext?,
        siblingTrackFiles: [URL]? = nil
    ) -> [DiscAuditIssue] {
        var issues: [DiscAuditIssue] = []
        let siblingTrackFiles = siblingTrackFiles ?? (
            isSheetFile(sheetURL)
                ? Self.siblingTrackFiles(near: sheetURL, referencedBy: references)
                : []
        )
        let inferredGame = redumpContext?.gameName ?? inferredGameName(redumpStatuses: redumpStatuses)
        var wrongTrackNumbers = Set<Int>()
        var smallTrackNumbers = Set<Int>()

        for ref in references {
            if let pair = repeatedFileTrackPair(in: ref) {
                appendUnique(
                    DiscAuditIssue(kind: .sameFileReferenced(
                        first: pair.first,
                        second: pair.second,
                        fileName: ref.name
                    )),
                    to: &issues
                )
            }

            if let cueTrack = ref.singleTrackNumber,
               let filenameTrack = filenameTrackNumber(in: ref.url),
               cueTrack != filenameTrack {
                appendUnique(
                    DiscAuditIssue(kind: .filenameTrackMismatch(
                        cueTrack: cueTrack,
                        filenameTrack: filenameTrack,
                        fileName: ref.name
                    )),
                    to: &issues
                )
            }
        }

        for (url, status) in redumpStatuses {
            guard let ref = references.first(where: { $0.url == url }) else { continue }
            switch status {
            case .wrongTrack(_, let expected, let found, let gameName):
                wrongTrackNumbers.insert(expected)
                appendUnique(
                    DiscAuditIssue(kind: .wrongTrack(
                        expected: expected,
                        found: found,
                        gameName: gameName
                    )),
                    to: &issues
                )
            case .verified(let candidates):
                if let redumpContext,
                   let track = ref.singleTrackNumber,
                   let inferredGame,
                   !candidates.contains(where: {
                       $0.platformKey == redumpContext.platformKey && $0.gameName == inferredGame
                   }),
                   let foundGame = candidates.first(where: { $0.gameName != inferredGame })?.gameName {
                    appendUnique(
                        DiscAuditIssue(kind: .differentGame(
                            track: track,
                            foundGame: foundGame,
                            expectedGame: inferredGame
                        )),
                        to: &issues
                    )
                }
            case .sizeMatchedButCRCMismatch, .unknown:
                break
            }
        }

        if let duplicate = duplicateTrackIssue(references: references, fingerprints: fingerprints) {
            appendUnique(
                DiscAuditIssue(kind: .duplicateTracks(first: duplicate.first, second: duplicate.second)),
                to: &issues
            )
        }

        for ref in references {
            guard let fingerprint = fingerprints[ref.url] else { continue }
            let track = ref.singleTrackNumber
            let expectedEntry = track.flatMap { redumpContext?.trackEntriesByNumber[$0] }

            if isUnexpectedlySmall(fingerprint: fingerprint, expectedEntry: expectedEntry) {
                if let track { smallTrackNumbers.insert(track) }
                appendUnique(
                    DiscAuditIssue(kind: .unexpectedlySmall(
                        track: track,
                        fileName: ref.name,
                        size: fingerprint.size
                    )),
                    to: &issues
                )
                continue
            }

            if let sectorSize = sectorSize(for: ref),
               sectorSize > 0,
               fingerprint.size % sectorSize != 0 {
                appendUnique(
                    DiscAuditIssue(kind: .sectorMisaligned(
                        track: track,
                        fileName: ref.name,
                        size: fingerprint.size
                    )),
                    to: &issues
                )
            }

            guard let track, let expectedEntry else { continue }
            if wrongTrackNumbers.contains(track) || smallTrackNumbers.contains(track) {
                continue
            }
            if fingerprint.size != expectedEntry.size {
                if isExpectedGDIPregapDelta(
                    sheetURL: sheetURL,
                    redumpContext: redumpContext,
                    track: track,
                    ref: ref,
                    fingerprintSize: fingerprint.size,
                    expectedSize: expectedEntry.size
                ) {
                    continue
                }
                appendUnique(
                    DiscAuditIssue(kind: .wrongSize(
                        track: track,
                        expected: expectedEntry.size,
                        actual: fingerprint.size
                    )),
                    to: &issues
                )
            } else if fingerprint.crc32 != expectedEntry.crc32 {
                appendUnique(
                    DiscAuditIssue(kind: .trackCorrupted(
                        track: track,
                        gameName: redumpContext?.gameName ?? expectedEntry.gameName
                    )),
                    to: &issues
                )
            }
        }

        if let redumpContext,
           let sheetFingerprint {
            let sheetExtension = sheetURL.pathExtension.lowercased()
            let matchingSheetEntries = redumpContext.sheetEntries.filter {
                ($0.romName as NSString).pathExtension.lowercased() == sheetExtension
            }
            if !matchingSheetEntries.isEmpty,
               !matchingSheetEntries.contains(where: {
                   $0.size == sheetFingerprint.size && $0.crc32 == sheetFingerprint.crc32
               }) {
                appendUnique(
                    DiscAuditIssue(kind: .cueChanged(gameName: redumpContext.gameName)),
                    to: &issues
                )
            }
        }

        for sibling in siblingTrackFiles {
            appendUnique(
                DiscAuditIssue(kind: .unreferencedTrack(
                    fileName: sibling.lastPathComponent,
                    track: filenameTrackNumber(in: sibling)
                )),
                to: &issues
            )
        }

        return issues
    }

    static func normalizedRedumpStatuses(
        sheetURL: URL,
        references: [DiscSheet.Reference],
        fingerprints: [URL: FileFingerprint],
        redumpStatuses: [URL: RedumpDatabase.Status],
        redumpContext: RedumpContext?
    ) -> [URL: RedumpDatabase.Status] {
        guard let redumpContext else { return redumpStatuses }
        var normalized = redumpStatuses

        for ref in references {
            guard let track = ref.singleTrackNumber,
                  let fingerprint = fingerprints[ref.url],
                  let expectedEntry = redumpContext.trackEntriesByNumber[track],
                  isExpectedGDIPregapDelta(
                      sheetURL: sheetURL,
                      redumpContext: redumpContext,
                      track: track,
                      ref: ref,
                      fingerprintSize: fingerprint.size,
                      expectedSize: expectedEntry.size
                  )
            else { continue }

            switch normalized[ref.url] {
            case .wrongTrack:
                continue
            default:
                normalized[ref.url] = .verified(candidates: [expectedEntry])
            }
        }

        return normalized
    }

    static func duplicateTrackIssue(
        references: [DiscSheet.Reference],
        fingerprints: [URL: FileFingerprint]
    ) -> (first: Int, second: Int)? {
        var seen: [FileFingerprint: (track: Int, url: URL)] = [:]
        for ref in references {
            guard let trackNumber = ref.singleTrackNumber,
                  let fingerprint = fingerprints[ref.url]
            else { continue }
            if let first = seen[fingerprint],
               first.track != trackNumber,
               first.url != ref.url {
                return (first.track, trackNumber)
            }
            seen[fingerprint] = (trackNumber, ref.url)
        }
        return nil
    }

    static func siblingTrackFiles(
        near sheetURL: URL,
        referencedBy references: [DiscSheet.Reference]
    ) -> [URL] {
        let directory = sheetURL.deletingLastPathComponent()
        let referencedPaths = Set(references.map { $0.url.standardizedFileURL.path })
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { url in
                guard url.pathExtension.lowercased() == "bin",
                      filenameTrackNumber(in: url) != nil,
                      !referencedPaths.contains(url.standardizedFileURL.path)
                else { return false }
                let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? true
                return isRegular
            }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    static func filenameTrackNumber(in url: URL) -> Int? {
        RedumpDatabase.Entry.trackNumber(in: url.lastPathComponent)
    }

    private static func repeatedFileTrackPair(in ref: DiscSheet.Reference) -> (first: Int, second: Int)? {
        guard ref.fileDirectiveCount > 1 else { return nil }
        var uniqueTracks: [Int] = []
        for track in ref.tracks where !uniqueTracks.contains(track.number) {
            uniqueTracks.append(track.number)
            if uniqueTracks.count == 2 {
                return (uniqueTracks[0], uniqueTracks[1])
            }
        }
        return nil
    }

    private static func isUnexpectedlySmall(
        fingerprint: FileFingerprint,
        expectedEntry: RedumpDatabase.Entry?
    ) -> Bool {
        if fingerprint.size < 2352 { return true }
        guard let expectedEntry else { return false }
        return fingerprint.size < max(2352, expectedEntry.size / 100)
    }

    /// Redump's Dreamcast DAT describes cue/bin-style tracks that include the
    /// standard 150-sector audio pregap. Native GDI track files omit that
    /// pregap, so accept this exact delta as format-equivalent.
    private static func isExpectedGDIPregapDelta(
        sheetURL: URL,
        redumpContext: RedumpContext?,
        track: Int,
        ref: DiscSheet.Reference,
        fingerprintSize: UInt64,
        expectedSize: UInt64
    ) -> Bool {
        guard sheetURL.pathExtension.lowercased() == "gdi" else { return false }
        guard redumpContext?.platformKey.lowercased() == "dreamcast" else { return false }
        guard track >= 2 else { return false }
        guard ref.tracks.contains(where: { $0.mode.uppercased() == "AUDIO" })
            || ref.url.pathExtension.lowercased() == "raw"
        else { return false }
        guard let sectorSize = sectorSize(for: ref), sectorSize > 0 else { return false }
        guard expectedSize > fingerprintSize else { return false }
        return expectedSize - fingerprintSize == UInt64(150) * sectorSize
    }

    private static func sectorSize(for ref: DiscSheet.Reference) -> UInt64? {
        for mode in ref.tracks.map(\.mode) {
            let parts = mode.split(separator: "/")
            if let last = parts.last,
               let size = UInt64(last) {
                return size
            }
            if mode.uppercased() == "AUDIO" {
                return 2352
            }
        }

        switch ref.url.pathExtension.lowercased() {
        case "bin", "raw":
            return 2352
        default:
            return nil
        }
    }

    private static func isSheetFile(_ url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "cue", "gdi", "toc":
            return true
        default:
            return false
        }
    }

    private static func uniqueBest(in counts: [String: Int]) -> String? {
        guard let best = counts.max(by: { $0.value < $1.value }), best.value > 0 else {
            return nil
        }
        let tied = counts.filter { $0.value == best.value }
        return tied.count == 1 ? best.key : nil
    }

    private static func countKey(platformKey: String, gameName: String) -> String {
        "\(platformKey)\u{1f}\(gameName)"
    }

    private static func identity(from countKey: String?) -> RedumpIdentity? {
        guard let countKey else { return nil }
        let parts = countKey.split(separator: "\u{1f}", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return RedumpIdentity(platformKey: String(parts[0]), gameName: String(parts[1]))
    }

    private static func appendUnique(_ issue: DiscAuditIssue, to issues: inout [DiscAuditIssue]) {
        if !issues.contains(issue) {
            issues.append(issue)
        }
    }
}

private extension RedumpDatabase.Entry {
    var redumpIdentity: DiscAudit.RedumpIdentity {
        DiscAudit.RedumpIdentity(platformKey: platformKey, gameName: gameName)
    }
}

private extension DiscAudit.RedumpIdentity {
    var countKey: String {
        "\(platformKey)\u{1f}\(gameName)"
    }
}
