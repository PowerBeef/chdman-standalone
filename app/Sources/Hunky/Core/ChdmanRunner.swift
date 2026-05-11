import Foundation

enum ChdmanError: LocalizedError {
    case binaryMissing
    case nonZeroExit(code: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .binaryMissing:
            return "chdman binary not found in app bundle."
        case .nonZeroExit(let code, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "chdman exited with code \(code)." : trimmed
        }
    }
}

struct ChdmanResult: Sendable {
    let stdout: String
    let stderr: String
}

protocol ChdmanRunning {
    func run(
        args: [String],
        onProgress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancelToken
    ) async throws -> ChdmanResult
}

final class ChdmanRunner: ChdmanRunning {

    static let shared = ChdmanRunner()

    private static var bundledBinaryURL: URL? {
        Bundle.main.url(forResource: "chdman", withExtension: nil)
    }

    func run(
        args: [String],
        onProgress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancelToken
    ) async throws -> ChdmanResult {

        guard let binary = Self.bundledBinaryURL else {
            throw ChdmanError.binaryMissing
        }

        let process = Process()
        process.executableURL = binary
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Aggregators
        let stdoutBuf = LineBuffer()
        let stderrBuf = LineBuffer()

        let progressForwarder = ProgressForwarder(onProgress: onProgress)

        // chdman emits progress to stderr as "Compressing, X.X% complete..."
        // We watch stderr line-by-line and forward percentages.
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrBuf.append(data)
            for line in stderrBuf.drainLines() {
                if let pct = Self.parsePercent(line: line) {
                    progressForwarder.forward(pct / 100.0)
                }
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stdoutBuf.append(data)
            _ = stdoutBuf.drainLines()
        }

        cancelToken.setOnCancel { [weak process] in
            guard let process, process.isRunning else { return }
            process.terminate()
        }
        defer {
            cancelToken.clearOnCancel()
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in
                cont.resume()
            }

            do {
                try process.run()
                if cancelToken.isCancelled, process.isRunning {
                    process.terminate()
                }
            } catch {
                process.terminationHandler = nil
                cont.resume(throwing: error)
            }
        }

        process.terminationHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdoutPipe.fileHandleForReading.readabilityHandler = nil

        // Drain remaining buffered output so we don't lose the tail.
        if let tailErr = try? stderrPipe.fileHandleForReading.readToEnd() {
            stderrBuf.append(tailErr)
        }
        if let tailOut = try? stdoutPipe.fileHandleForReading.readToEnd() {
            stdoutBuf.append(tailOut)
        }
        let stdoutText = stdoutBuf.fullText()
        let stderrText = stderrBuf.fullText()

        if process.terminationStatus != 0 {
            throw ChdmanError.nonZeroExit(code: process.terminationStatus, stderr: stderrText)
        }

        return ChdmanResult(stdout: stdoutText, stderr: stderrText)
    }

    // chdman progress lines look like:
    //   "Compressing, 12.3% complete... (ratio=42.1%)"
    //   "Verifying, 99.9% complete..."
    private static let percentRegex =
        try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*%\s*complete"#, options: [.caseInsensitive])

    static func parsePercent(line: String) -> Double? {
        let range = NSRange(line.startIndex..., in: line)
        guard let m = percentRegex.firstMatch(in: line, range: range),
              m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: line) else { return nil }
        return Double(line[r])
    }
}

final class CancelToken: @unchecked Sendable {
    private let lock = NSLock()
    private var _cancelled = false
    private var onCancel: (() -> Void)?

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _cancelled
    }

    func setOnCancel(_ callback: @escaping () -> Void) {
        lock.lock()
        let alreadyCancelled = _cancelled
        if alreadyCancelled {
            lock.unlock()
            callback()
        } else {
            onCancel = callback
            lock.unlock()
        }
    }

    func clearOnCancel() {
        lock.lock()
        onCancel = nil
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        _cancelled = true
        let cb = onCancel
        lock.unlock()
        cb?()
    }
}

private final class ProgressForwarder: @unchecked Sendable {
    private let lock = NSLock()
    private let onProgress: @Sendable (Double) -> Void
    private var lastProgress: Double = -1
    private var lastForward = Date.distantPast
    private let throttleInterval: TimeInterval = 0.2

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func forward(_ value: Double) {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        let significant = abs(value - lastProgress) >= 0.01
        let due = now.timeIntervalSince(lastForward) >= throttleInterval
        let complete = value >= 1.0
        guard significant && (due || complete) else { return }
        lastProgress = value
        lastForward = now
        onProgress(value)
    }
}

// Thread-safe buffer that accumulates Data and yields complete \r- or \n-terminated lines.
// chdman sometimes uses \r for in-place progress updates, so we treat \r as a line break too.
final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var allText = ""

    func append(_ chunk: Data) {
        lock.lock(); defer { lock.unlock() }
        data.append(chunk)
        if let s = String(data: chunk, encoding: .utf8) {
            allText.append(s)
        }
    }

    func drainLines() -> [String] {
        lock.lock(); defer { lock.unlock() }
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let separators: Set<Character> = ["\n", "\r"]
        var lines: [String] = []
        var current = ""
        let lastTerminated = text.last.map { separators.contains($0) } ?? false
        for ch in text {
            if separators.contains(ch) {
                if !current.isEmpty { lines.append(current) }
                current = ""
            } else {
                current.append(ch)
            }
        }
        // Anything after the final terminator is incomplete; keep it in the buffer.
        if lastTerminated {
            data.removeAll(keepingCapacity: true)
        } else {
            if let lastSepIndex = text.lastIndex(where: { separators.contains($0) }) {
                let tail = String(text[text.index(after: lastSepIndex)...])
                data = Data(tail.utf8)
            }
        }
        return lines
    }

    func fullText() -> String {
        lock.lock(); defer { lock.unlock() }
        return allText
    }
}
