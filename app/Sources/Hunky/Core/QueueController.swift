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
        let existing = Set(items.map(\.url))
        for url in urls where !existing.contains(url) {
            guard let kind = InputKind.detect(url: url) else { continue }
            items.append(FileItem(url: url, kind: kind))
        }
    }

    func remove(_ item: FileItem) {
        if case .running = item.status { return } // don't remove a running item
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll { itemIsRemovable($0) }
    }

    private func itemIsRemovable(_ item: FileItem) -> Bool {
        switch item.status {
        case .running: return false
        default:       return true
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
                // best-effort: remove a partially written output
                if let out = plan.outputURL {
                    try? FileManager.default.removeItem(at: out)
                }
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
            } else {
                item.status = .failed(message: (error as? LocalizedError)?.errorDescription ?? "\(error)")
            }
        }
    }

    // MARK: - Argument plans

    private struct ExecutionPlan {
        let args: [String]
        let outputURL: URL?
    }

    private func makePlan(for item: FileItem) throws -> ExecutionPlan {
        let baseDir = outputDirectory ?? item.url.deletingLastPathComponent()
        let stem = item.url.deletingPathExtension().lastPathComponent

        switch item.action {
        case .createCD:
            let out = uniqueURL(in: baseDir, stem: stem, ext: "chd")
            return ExecutionPlan(
                args: ["createcd", "-i", item.url.path, "-o", out.path, "-f"],
                outputURL: out
            )
        case .extractCD:
            let outCue = uniqueURL(in: baseDir, stem: stem, ext: "cue")
            let outBin = baseDir.appendingPathComponent("\(outCue.deletingPathExtension().lastPathComponent).bin")
            return ExecutionPlan(
                args: ["extractcd", "-i", item.url.path, "-o", outCue.path, "-ob", outBin.path, "-f"],
                outputURL: outCue
            )
        case .info:
            return ExecutionPlan(args: ["info", "-i", item.url.path], outputURL: nil)
        case .verify:
            return ExecutionPlan(args: ["verify", "-i", item.url.path], outputURL: nil)
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
}
