import Foundation

struct DiscAuditIssue: Equatable, Identifiable, Sendable {
    let kind: Kind

    enum Kind: Equatable, Sendable {
        case wrongTrack(expected: Int, found: Int, gameName: String)
        case sameFileReferenced(first: Int, second: Int, fileName: String)
        case duplicateTracks(first: Int, second: Int)
        case trackCorrupted(track: Int, gameName: String)
        case wrongSize(track: Int, expected: UInt64, actual: UInt64)
        case differentGame(track: Int, foundGame: String, expectedGame: String)
        case cueChanged(gameName: String)
        case filenameTrackMismatch(cueTrack: Int, filenameTrack: Int, fileName: String)
        case unreferencedTrack(fileName: String, track: Int?)
        case sectorMisaligned(track: Int?, fileName: String, size: UInt64)
        case unexpectedlySmall(track: Int?, fileName: String, size: UInt64)
    }

    var id: String { message + help }

    var message: String {
        switch kind {
        case .wrongTrack(let expected, let found, _):
            return "Track \(expected) appears to be Track \(found)"
        case .sameFileReferenced(let first, let second, _):
            return "Tracks \(first) and \(second) reference the same file"
        case .duplicateTracks(let first, let second):
            return "Tracks \(first) and \(second) are identical"
        case .trackCorrupted(let track, _):
            return "Track \(track) looks corrupted"
        case .wrongSize(let track, _, _):
            return "Track \(track) has the wrong size"
        case .differentGame(let track, _, _):
            return "Track \(track) matches a different game"
        case .cueChanged:
            return "Cue sheet differs from Redump"
        case .filenameTrackMismatch:
            return "Cue track number does not match filename"
        case .unreferencedTrack:
            return "Unreferenced track file found"
        case .sectorMisaligned(let track, let fileName, _):
            return track.map { "Track \($0) is not sector aligned" }
                ?? "\(fileName) is not sector aligned"
        case .unexpectedlySmall(let track, let fileName, _):
            return track.map { "Track \($0) is unexpectedly small" }
                ?? "\(fileName) is unexpectedly small"
        }
    }

    var help: String {
        switch kind {
        case .wrongTrack(let expected, let found, let gameName):
            return "This file matches Redump's Track \(found) for \(gameName), but the cue lists it as Track \(expected)."
        case .sameFileReferenced(_, _, let fileName):
            return "The cue assigns multiple tracks to \(fileName) through repeated FILE entries. That usually means one track points at another track's data."
        case .duplicateTracks:
            return "Two cue tracks have the same size and CRC32. This usually means one track was copied over another."
        case .trackCorrupted(let track, let gameName):
            return "Track \(track) has the expected Redump size for \(gameName), but its CRC32 differs."
        case .wrongSize(_, let expected, let actual):
            return "Expected \(expected) bytes from Redump, but found \(actual) bytes locally."
        case .differentGame(_, let foundGame, let expectedGame):
            return "This track matches \(foundGame), while the rest of the disc looks like \(expectedGame)."
        case .cueChanged(let gameName):
            return "The data tracks identify \(gameName), but the cue sheet's size or CRC32 differs from Redump."
        case .filenameTrackMismatch(let cueTrack, let filenameTrack, let fileName):
            return "The cue declares Track \(cueTrack), but the filename \(fileName) looks like Track \(filenameTrack)."
        case .unreferencedTrack(let fileName, let track):
            if let track {
                return "\(fileName) looks like Track \(track), but no cue FILE entry references it."
            }
            return "\(fileName) looks like a track file, but no cue FILE entry references it."
        case .sectorMisaligned(_, _, let size):
            return "Disc tracks should normally be a whole number of sectors; this file is \(size) bytes."
        case .unexpectedlySmall(_, _, let size):
            return "This track is only \(size) bytes, which is far smaller than expected for a disc track."
        }
    }
}
