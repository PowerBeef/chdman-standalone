import Foundation

/// Lightweight parser for the file-references in a CUE/GDI/TOC sheet.
///
/// Hunky doesn't need to *understand* the cue (chdman does that). All we
/// want at queue time is: "what data files does this sheet reference,
/// and do they exist on disk?" — so the user gets a green check or a
/// red warning before they hit Start.
enum CueSheet {

    struct Track: Equatable, Sendable {
        let number: Int
        let mode: String
    }

    struct Reference: Equatable, Sendable {
        let url: URL
        let exists: Bool
        var tracks: [Track]
        var name: String { url.lastPathComponent }

        var singleTrackNumber: Int? {
            tracks.count == 1 ? tracks[0].number : nil
        }
    }

    /// Parse `FILE "name.bin" BINARY`-style references out of the sheet
    /// at `sheetURL`. Resolves relative paths against the sheet's folder.
    /// Returns an empty array if the sheet can't be read or has no FILE
    /// directives. Order is preserved; duplicates are dropped.
    static func references(in sheetURL: URL) -> [Reference] {
        guard let raw = try? String(contentsOf: sheetURL, encoding: .utf8) else {
            // Try a forgiving fallback for non-UTF8 cue files (some games
            // ship Latin-1 encoded CUEs).
            guard let data = try? Data(contentsOf: sheetURL),
                  let raw = String(data: data, encoding: .isoLatin1)
            else { return [] }
            return parse(text: raw, baseDir: sheetURL.deletingLastPathComponent())
        }
        return parse(text: raw, baseDir: sheetURL.deletingLastPathComponent())
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

    private static func parse(text: String, baseDir: URL) -> [Reference] {
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
                } else {
                    currentIndex = refs.firstIndex { $0.url.path == url.path }
                }
                continue
            }

            if let track = track(in: line), let currentIndex {
                refs[currentIndex].tracks.append(track)
            }
        }

        return refs
    }

    private static func fileName(in line: String) -> String? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = cueFileLine.firstMatch(in: line, range: range) else { return nil }
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
}
