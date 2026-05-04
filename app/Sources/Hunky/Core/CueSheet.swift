import Foundation

/// Lightweight parser for the file-references in a CUE/GDI/TOC sheet.
///
/// Hunky doesn't need to *understand* the cue (chdman does that). All we
/// want at queue time is: "what data files does this sheet reference,
/// and do they exist on disk?" — so the user gets a green check or a
/// red warning before they hit Start.
enum CueSheet {

    struct Reference: Equatable {
        let url: URL
        let exists: Bool
        var name: String { url.lastPathComponent }
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
        pattern: #"(?im)^\s*FILE\s+(?:"([^"]+)"|(\S+))"#
    )

    private static func parse(text: String, baseDir: URL) -> [Reference] {
        var seen = Set<String>()
        var refs: [Reference] = []
        let nsText = text as NSString
        let full = NSRange(location: 0, length: nsText.length)

        cueFileLine.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match else { return }
            let name = firstNonEmptyCapture(match: match, in: text, indices: [1, 2])
            guard let name, !name.isEmpty else { return }

            let url = URL(fileURLWithPath: name, relativeTo: baseDir).standardizedFileURL
            guard seen.insert(url.path).inserted else { return }

            let exists = FileManager.default.fileExists(atPath: url.path)
            refs.append(Reference(url: url, exists: exists))
        }

        return refs
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
}
