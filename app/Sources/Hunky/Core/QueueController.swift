import Foundation
import Observation

@Observable
@MainActor
final class QueueController {
    var items: [FileItem] = []
    var isRunning: Bool = false
    var outputDirectory: URL? = nil   // nil = same as source

    private var currentToken: CancelToken?

    // MARK: - Add / remove

    func add(urls: [URL]) {
        var existing = Set(items.map { $0.url.standardizedFileURL })
        for url in Self.expandInputURLs(urls) where !existing.contains(url) {
            guard let kind = InputKind.detect(url: url) else { continue }
            let item = FileItem(url: url, kind: kind)
            items.append(item)
            existing.insert(url)
            scheduleRedumpMatch(for: item)
        }
    }

    private static func expandInputURLs(_ urls: [URL]) -> [URL] {
        urls.flatMap { url -> [URL] in
            let standardized = url.standardizedFileURL
            if isDirectory(standardized) {
                return supportedFiles(in: standardized)
            }
            return [standardized]
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private static func supportedFiles(in directory: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator {
            guard InputKind.detect(url: url) != nil else { continue }
            let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? true
            if isRegular {
                files.append(url.standardizedFileURL)
            }
        }
        return files.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }

    /// Background-hash each referenced bin and resolve it against the
    /// Redump index. This populates `item.redumpStatuses` lazily so the
    /// UI can show "verified" / "corrupted" without blocking the queue.
    private func scheduleRedumpMatch(for item: FileItem) {
        guard !item.references.isEmpty else { return }
        item.redumpInProgress = true
        let refs = item.references.filter { $0.exists }
        let itemID = item.id

        Task.detached(priority: .utility) { [weak self] in
            for ref in refs {
                let url = ref.url
                // Use resourceValues — it follows symlinks. FileManager.attributesOfItem
                // returns the symlink's own size on macOS, which gives bogus matches
                // (a 92-byte symlink will "size-match" any 92-byte cue file in Redump).
                let resolved = url.resolvingSymlinksInPath()
                let size = (try? resolved.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                    .flatMap { UInt64(exactly: $0) } ?? 0
                guard let crc = CRC32.file(at: url) else { continue }
                let fingerprint = FileFingerprint(size: size, crc32: crc)
                let status = await RedumpDatabase.shared.match(
                    crc32: crc,
                    size: size,
                    expectedTrackNumber: ref.singleTrackNumber
                )

                await MainActor.run { [weak self] in
                    guard let self,
                          let live = self.items.first(where: { $0.id == itemID })
                    else { return }
                    live.referenceFingerprints[url] = fingerprint
                    live.redumpStatuses[url] = status
                }
            }
            await MainActor.run { [weak self] in
                guard let self,
                      let live = self.items.first(where: { $0.id == itemID })
                else { return }
                live.redumpInProgress = false
            }
        }
    }

    func remove(_ item: FileItem) {
        if case .running = item.status { return } // don't remove a running item
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll { itemIsFinished($0) }
    }

    private func itemIsFinished(_ item: FileItem) -> Bool {
        switch item.status {
        case .done, .failed, .cancelled: return true
        case .idle, .running:            return false
        }
    }

    // MARK: - Run

    func start() {
        guard !isRunning else { return }
        guard items.contains(where: { isPending($0) }) else { return }
        isRunning = true
        Task { await runLoop() }
    }

    func cancel() {
        currentToken?.cancel()
    }

    private func isPending(_ item: FileItem) -> Bool {
        if case .idle = item.status { return true }
        return false
    }

    private func runLoop() async {
        defer { isRunning = false }
        for item in items where isPending(item) {
            await run(item: item)
            if let token = currentToken, token.isCancelled {
                // Mark remaining pending items as cancelled
                for remaining in items where isPending(remaining) {
                    remaining.status = .cancelled
                }
                return
            }
        }
    }

    private func run(item: FileItem) async {
        let token = CancelToken()
        currentToken = token
        item.status = .running(progress: 0)

        let plan: ExecutionPlan
        do {
            plan = try makePlan(for: item)
        } catch {
            item.status = .failed(message: (error as? LocalizedError)?.errorDescription ?? "\(error)")
            return
        }

        do {
            let result = try await ChdmanRunner.shared.run(
                args: plan.args,
                onProgress: { [weak self, weak item] pct in
                    guard let self, let item else { return }
                    Task { @MainActor in
                        // Don't downgrade a finished status
                        if case .running = item.status {
                            item.status = .running(progress: max(0, min(1, pct)))
                        }
                        _ = self
                    }
                },
                cancelToken: token
            )

            if token.isCancelled {
                item.status = .cancelled
                removePlannedOutputs(plan.cleanupURLs)
                return
            }

            if let out = plan.outputURL {
                item.outputURL = out
            }
            switch item.action {
            case .info:
                item.infoOutput = result.stdout.isEmpty ? result.stderr : result.stdout
                item.status = .done(message: nil)
            case .verify:
                item.status = .done(message: "Verified ok")
            case .createCD, .extractCD:
                item.status = .done(message: nil)
            }
        } catch {
            if token.isCancelled {
                item.status = .cancelled
                removePlannedOutputs(plan.cleanupURLs)
            } else {
                item.status = .failed(message: (error as? LocalizedError)?.errorDescription ?? "\(error)")
            }
        }
    }

    // MARK: - Argument plans

    private struct ExecutionPlan {
        let args: [String]
        let outputURL: URL?
        let cleanupURLs: [URL]
    }

    private func makePlan(for item: FileItem) throws -> ExecutionPlan {
        let baseDir = outputDirectory ?? item.url.deletingLastPathComponent()
        let stem = item.url.deletingPathExtension().lastPathComponent

        switch item.action {
        case .createCD:
            let out = uniqueURL(in: baseDir, stem: stem, ext: "chd")
            return ExecutionPlan(
                args: ["createcd", "-i", item.url.path, "-o", out.path, "-f"],
                outputURL: out,
                cleanupURLs: [out]
            )
        case .extractCD:
            let (outCue, outBin) = uniqueURLPair(
                in: baseDir,
                stem: stem,
                primaryExt: "cue",
                secondaryExt: "bin"
            )
            return ExecutionPlan(
                args: ["extractcd", "-i", item.url.path, "-o", outCue.path, "-ob", outBin.path, "-f"],
                outputURL: outCue,
                cleanupURLs: [outCue, outBin]
            )
        case .info:
            return ExecutionPlan(
                args: ["info", "-i", item.url.path],
                outputURL: nil,
                cleanupURLs: []
            )
        case .verify:
            return ExecutionPlan(
                args: ["verify", "-i", item.url.path],
                outputURL: nil,
                cleanupURLs: []
            )
        }
    }

    private func uniqueURL(in dir: URL, stem: String, ext: String) -> URL {
        let candidate = dir.appendingPathComponent("\(stem).\(ext)")
        if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        var i = 2
        while true {
            let next = dir.appendingPathComponent("\(stem) (\(i)).\(ext)")
            if !FileManager.default.fileExists(atPath: next.path) { return next }
            i += 1
        }
    }

    private func uniqueURLPair(
        in dir: URL,
        stem: String,
        primaryExt: String,
        secondaryExt: String
    ) -> (URL, URL) {
        var i = 1
        while true {
            let suffix = i == 1 ? "" : " (\(i))"
            let baseName = "\(stem)\(suffix)"
            let primary = dir.appendingPathComponent("\(baseName).\(primaryExt)")
            let secondary = dir.appendingPathComponent("\(baseName).\(secondaryExt)")
            if !FileManager.default.fileExists(atPath: primary.path),
               !FileManager.default.fileExists(atPath: secondary.path) {
                return (primary, secondary)
            }
            i += 1
        }
    }

    private func removePlannedOutputs(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
