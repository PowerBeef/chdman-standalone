import Foundation

/// Lightweight parser for the file-references in a CUE/GDI/TOC sheet.
///
/// Hunky doesn't need to *understand* the cue (chdman does that). All we
/// want at queue time is: "what data files does this sheet reference,
/// and do they exist on disk?" — so the user gets a green check or a
/// red warning before they hit Start.
enum DiscSheet {

    struct Track: Equatable, Sendable {
        let number: Int
        let mode: String
    }

    struct Reference: Equatable, Sendable {
        let url: URL
        let exists: Bool
        var tracks: [Track]
        var fileDirectiveCount: Int = 1
        var name: String { url.lastPathComponent }

        var singleTrackNumber: Int? {
            tracks.count == 1 ? tracks[0].number : nil
        }
    }

    /// Parse referenced data files out of a CUE/GDI/TOC sheet. Resolves
    /// relative paths against the sheet's folder. Order is preserved;
    /// duplicate entries are merged while retaining a count so the audit can
    /// flag reused references.
    static func references(in sheetURL: URL) -> [Reference] {
        guard let raw = try? String(contentsOf: sheetURL, encoding: .utf8) else {
            // Try a forgiving fallback for non-UTF8 cue files (some games
            // ship Latin-1 encoded CUEs).
            guard let data = try? Data(contentsOf: sheetURL),
                  let raw = String(data: data, encoding: .isoLatin1)
            else { return [] }
            return parse(text: raw, sheetURL: sheetURL)
        }
        return parse(text: raw, sheetURL: sheetURL)
    }

    // MARK: - Internals

    /// Matches the filename portion of a CUE `FILE` line, supporting:
    ///   FILE "name with spaces.bin" BINARY
    ///   FILE name.bin BINARY
    /// The optional trailing token (BINARY/WAVE/MP3/...) is ignored.
    private static let cueFileLine = try! NSRegularExpression(
        pattern: #"^\s*FILE\s+(?:"([^"]+)"|(\S+))"#,
        options: [.caseInsensitive]
    )

    private static let cueTrackLine = try! NSRegularExpression(
        pattern: #"^\s*TRACK\s+(\d{1,3})\s+(\S+)"#,
        options: [.caseInsensitive]
    )

    private static let tocFileLine = try! NSRegularExpression(
        pattern: #"^\s*(?:FILE|DATAFILE|AUDIOFILE)\s+(?:"([^"]+)"|(\S+))"#,
        options: [.caseInsensitive]
    )

    private static func parse(text: String, sheetURL: URL) -> [Reference] {
        switch sheetURL.pathExtension.lowercased() {
        case "gdi":
            return parseGDI(text: text, baseDir: sheetURL.deletingLastPathComponent())
        case "toc":
            return parseTOC(text: text, baseDir: sheetURL.deletingLastPathComponent())
        default:
            return parseCue(text: text, baseDir: sheetURL.deletingLastPathComponent())
        }
    }

    private static func parseCue(text: String, baseDir: URL) -> [Reference] {
        var seen = Set<String>()
        var refs: [Reference] = []
        var currentIndex: Int?

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            if let name = fileName(in: line), !name.isEmpty {
                let url = URL(fileURLWithPath: name, relativeTo: baseDir).standardizedFileURL
                if seen.insert(url.path).inserted {
                    let exists = FileManager.default.fileExists(atPath: url.path)
                    refs.append(Reference(url: url, exists: exists, tracks: []))
                    currentIndex = refs.count - 1
                } else if let existingIndex = refs.firstIndex(where: { $0.url.path == url.path }) {
                    refs[existingIndex].fileDirectiveCount += 1
                    currentIndex = existingIndex
                }
                continue
            }

            if let track = track(in: line), let currentIndex {
                refs[currentIndex].tracks.append(track)
            }
        }

        return refs
    }

    private static func parseGDI(text: String, baseDir: URL) -> [Reference] {
        var refs: [Reference] = []
        var seen = Set<String>()
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)

        for line in lines.dropFirst() {
            let tokens = tokenize(line)
            guard tokens.count >= 5,
                  let trackNumber = Int(tokens[0])
            else { continue }

            let name = tokens[4]
            let url = URL(fileURLWithPath: name, relativeTo: baseDir).standardizedFileURL
            let mode = gdiMode(trackType: tokens[safe: 2], sectorSize: tokens[safe: 3])
            let track = Track(number: trackNumber, mode: mode)

            if seen.insert(url.path).inserted {
                let exists = FileManager.default.fileExists(atPath: url.path)
                refs.append(Reference(url: url, exists: exists, tracks: [track]))
            } else if let existingIndex = refs.firstIndex(where: { $0.url.path == url.path }) {
                refs[existingIndex].tracks.append(track)
                refs[existingIndex].fileDirectiveCount += 1
            }
        }

        return refs
    }

    private static func parseTOC(text: String, baseDir: URL) -> [Reference] {
        var seen = Set<String>()
        var refs: [Reference] = []
        var currentTrack: Track?

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            if let track = track(in: line) {
                currentTrack = track
                continue
            }
            if let name = tocFileName(in: line), !name.isEmpty {
                let url = URL(fileURLWithPath: name, relativeTo: baseDir).standardizedFileURL
                let tracks = currentTrack.map { [$0] } ?? []
                if seen.insert(url.path).inserted {
                    let exists = FileManager.default.fileExists(atPath: url.path)
                    refs.append(Reference(url: url, exists: exists, tracks: tracks))
                } else if let existingIndex = refs.firstIndex(where: { $0.url.path == url.path }) {
                    refs[existingIndex].tracks.append(contentsOf: tracks)
                    refs[existingIndex].fileDirectiveCount += 1
                }
            }
        }

        return refs
    }

    private static func fileName(in line: String) -> String? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = cueFileLine.firstMatch(in: line, range: range) else { return nil }
        return firstNonEmptyCapture(match: match, in: line, indices: [1, 2])
    }

    private static func tocFileName(in line: String) -> String? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = tocFileLine.firstMatch(in: line, range: range) else { return nil }
        return firstNonEmptyCapture(match: match, in: line, indices: [1, 2])
    }

    private static func track(in line: String) -> Track? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = cueTrackLine.firstMatch(in: line, range: range),
              let numberString = capture(match: match, in: line, index: 1),
              let number = Int(numberString),
              let mode = capture(match: match, in: line, index: 2)
        else { return nil }
        return Track(number: number, mode: mode)
    }

    private static func firstNonEmptyCapture(
        match: NSTextCheckingResult,
        in text: String,
        indices: [Int]
    ) -> String? {
        for i in indices {
            let r = match.range(at: i)
            guard r.location != NSNotFound, let swiftRange = Range(r, in: text) else { continue }
            let captured = String(text[swiftRange])
            if !captured.isEmpty { return captured }
        }
        return nil
    }

    private static func capture(
        match: NSTextCheckingResult,
        in text: String,
        index: Int
    ) -> String? {
        let r = match.range(at: index)
        guard r.location != NSNotFound, let swiftRange = Range(r, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private static func gdiMode(trackType: String?, sectorSize: String?) -> String {
        if trackType == "0" {
            return "AUDIO"
        }
        if let sectorSize {
            return "MODE1/\(sectorSize)"
        }
        return "MODE1"
    }

    private static func tokenize(_ line: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
                continue
            }
            if char.isWhitespace, !inQuotes {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}

typealias CueSheet = DiscSheet

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
