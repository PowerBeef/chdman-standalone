import Foundation
import Darwin
import Observation

@Observable
@MainActor
final class QueueController {
    var items: [FileItem] = []
    var isRunning: Bool = false
    var outputDirectory: URL? = nil   // nil = same as source
    var lastRunSummary: RunSummary? = nil

    private var currentToken: CancelToken?
    private let runner: ChdmanRunning

    init(runner: ChdmanRunning = ChdmanRunner.shared) {
        self.runner = runner
    }

    // MARK: - Add / remove

    @discardableResult
    func add(
        urls: [URL],
        defaultActionFor: (InputKind) -> Action = Action.defaultAction(for:)
    ) async -> IntakeResult {
        let defaults = IntakeDefaults(
            cdImage: Self.validDefaultAction(defaultActionFor(.cdImage), for: .cdImage),
            chd: Self.validDefaultAction(defaultActionFor(.chd), for: .chd)
        )
        let existingAtStart = Set(items.map { $0.url.standardizedFileURL })
        let prepared = await Task.detached(priority: .userInitiated) {
            Self.prepareIntake(urls: urls, existing: existingAtStart, defaults: defaults)
        }.value

        var existingNow = Set(items.map { $0.url.standardizedFileURL })
        var result = prepared.result
        for preparedItem in prepared.items {
            guard !existingNow.contains(preparedItem.url) else {
                result.duplicates += 1
                continue
            }
            let item = FileItem(
                url: preparedItem.url,
                kind: preparedItem.kind,
                action: preparedItem.action,
                preparedMetadata: preparedItem.metadata
            )
            items.append(item)
            existingNow.insert(preparedItem.url)
            result.added += 1
            scheduleDiscAudit(for: item)
        }
        return result
    }

    private struct IntakeDefaults: Sendable {
        let cdImage: Action
        let chd: Action

        func action(for kind: InputKind) -> Action {
            switch kind {
            case .cdImage: return cdImage
            case .chd:     return chd
            }
        }
    }

    private struct PreparedIntake: Sendable {
        var result: IntakeResult
        var items: [PreparedIntakeItem]
    }

    private struct PreparedIntakeItem: Sendable {
        let url: URL
        let kind: InputKind
        let action: Action
        let metadata: FileItem.PreparedMetadata
    }

    private struct ExpandedInput {
        var urls: [URL] = []
        var emptyFolders: Int = 0
    }

    nonisolated private static func validDefaultAction(_ action: Action, for kind: InputKind) -> Action {
        Action.defaultActions(for: kind).contains(action) ? action : Action.defaultAction(for: kind)
    }

    nonisolated private static func prepareIntake(
        urls: [URL],
        existing: Set<URL>,
        defaults: IntakeDefaults
    ) -> PreparedIntake {
        let expanded = expandInputURLs(urls)
        var seen = existing
        var result = IntakeResult(emptyFolders: expanded.emptyFolders)
        var items: [PreparedIntakeItem] = []

        for url in expanded.urls {
            guard let kind = InputKind.detect(url: url) else {
                result.unsupported += 1
                continue
            }
            guard !seen.contains(url) else {
                result.duplicates += 1
                continue
            }
            seen.insert(url)
            items.append(
                PreparedIntakeItem(
                    url: url,
                    kind: kind,
                    action: defaults.action(for: kind),
                    metadata: FileItem.prepareMetadata(url: url, kind: kind)
                )
            )
        }

        return PreparedIntake(result: result, items: items)
    }

    nonisolated private static func expandInputURLs(_ urls: [URL]) -> ExpandedInput {
        var result = ExpandedInput()
        for url in urls {
            let standardized = url.standardizedFileURL
            if isDirectory(standardized) {
                let files = supportedFiles(in: standardized)
                if files.isEmpty {
                    result.emptyFolders += 1
                } else {
                    result.urls.append(contentsOf: files)
                }
            } else {
                result.urls.append(standardized)
            }
        }
        return result
    }

    nonisolated private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    nonisolated private static func supportedFiles(in directory: URL) -> [URL] {
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
    /// Redump index. This also runs the broader disc audit so the UI can
    /// surface structural warnings without blocking the queue.
    private func scheduleDiscAudit(for item: FileItem) {
        guard !item.references.isEmpty else { return }
        item.redumpInProgress = true
        item.auditIssues = []
        item.sheetFingerprint = nil
        item.referenceFingerprints = [:]
        item.redumpStatuses = [:]
        item.redumpUnavailablePlatform = nil
        let references = item.references
        let refs = references.filter { $0.exists }
        let itemID = item.id
        let sheetURL = item.url
        let detectedPlatform = item.identity?.platform
        let platformAliases = detectedPlatform.flatMap(RedumpDatabase.platformAliases(for:))

        Task.detached(priority: .utility) { [weak self] in
            var referenceFingerprints: [URL: FileFingerprint] = [:]
            var redumpStatuses: [URL: RedumpDatabase.Status] = [:]
            let platformKeys = if let platformAliases {
                await RedumpDatabase.shared.bundledPlatformKeys(matching: platformAliases)
            } else {
                Optional<[String]>.none
            }
            let unavailablePlatform = (platformAliases != nil && platformKeys?.isEmpty == true)
                ? detectedPlatform
                : nil

            for ref in refs {
                let url = ref.url
                guard let fingerprint = FileFingerprint.file(at: url) else { continue }
                let status = await RedumpDatabase.shared.match(
                    crc32: fingerprint.crc32,
                    size: fingerprint.size,
                    expectedTrackNumber: ref.singleTrackNumber,
                    platformKeys: platformKeys
                )
                referenceFingerprints[url] = fingerprint
                redumpStatuses[url] = status
            }

            let sheetFingerprint = Self.isRedumpSheet(sheetURL)
                ? FileFingerprint.file(at: sheetURL)
                : nil
            let inferredIdentity = DiscAudit.inferredGameIdentity(redumpStatuses: redumpStatuses)
            let redumpContext: DiscAudit.RedumpContext? = if let inferredIdentity {
                await RedumpDatabase.shared.redumpContext(identity: inferredIdentity)
            } else {
                nil
            }
            let normalizedRedumpStatuses = DiscAudit.normalizedRedumpStatuses(
                sheetURL: sheetURL,
                references: references,
                fingerprints: referenceFingerprints,
                redumpStatuses: redumpStatuses,
                redumpContext: redumpContext
            )
            let auditIssues = DiscAudit.evaluate(
                sheetURL: sheetURL,
                references: references,
                fingerprints: referenceFingerprints,
                redumpStatuses: normalizedRedumpStatuses,
                sheetFingerprint: sheetFingerprint,
                redumpContext: redumpContext
            )
            let finalReferenceFingerprints = referenceFingerprints
            let finalRedumpStatuses = normalizedRedumpStatuses

            await MainActor.run { [weak self] in
                guard let self,
                      let live = self.items.first(where: { $0.id == itemID })
                else { return }
                live.referenceFingerprints = finalReferenceFingerprints
                live.redumpStatuses = finalRedumpStatuses
                live.sheetFingerprint = sheetFingerprint
                live.auditIssues = auditIssues
                live.redumpUnavailablePlatform = unavailablePlatform
                live.redumpInProgress = false
            }
        }
    }

    nonisolated private static func isRedumpSheet(_ url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "cue", "gdi", "toc":
            return true
        default:
            return false
        }
    }

    func remove(_ item: FileItem) {
        guard !isRunning else { return }
        if case .running = item.status { return } // don't remove a running item
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll { itemIsFinished($0) }
    }

    func retry(_ item: FileItem) {
        guard !isRunning else { return }
        switch item.status {
        case .failed, .cancelled:
            item.status = .idle
            item.outputURL = nil
            item.infoOutput = nil
            item.logOutput = nil
        case .idle, .running, .done:
            return
        }
    }

    func retryFailed() {
        guard !isRunning else { return }
        for item in items {
            retry(item)
        }
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
        let runIDs = Set(items.filter { isPending($0) }.map(\.id))
        guard !runIDs.isEmpty else { return }
        lastRunSummary = nil
        isRunning = true
        Task { await runLoop(runIDs: runIDs) }
    }

    func cancel() {
        currentToken?.cancel()
    }

    private func isPending(_ item: FileItem) -> Bool {
        if case .idle = item.status { return true }
        return false
    }

    private func runLoop(runIDs: Set<UUID>) async {
        let startedAt = Date()
        defer {
            let summary = makeRunSummary(runIDs: runIDs, startedAt: startedAt, endedAt: Date())
            currentToken = nil
            isRunning = false
            lastRunSummary = summary
        }

        while let item = items.first(where: { runIDs.contains($0.id) && isPending($0) }) {
            await run(item: item)
            if let token = currentToken, token.isCancelled {
                // Mark remaining pending items as cancelled
                for remaining in items where runIDs.contains(remaining.id) && isPending(remaining) {
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
        item.outputURL = nil
        item.infoOutput = nil
        item.logOutput = nil

        let plan: ExecutionPlan
        do {
            plan = try makePlan(for: item)
        } catch {
            item.status = .failed(message: (error as? LocalizedError)?.errorDescription ?? "\(error)")
            return
        }

        do {
            let result = try await runner.run(
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
            item.logOutput = Self.combinedLog(stdout: result.stdout, stderr: result.stderr)
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
                removePlannedOutputs(plan.cleanupURLs)
                if case ChdmanError.nonZeroExit(_, let stderr) = error {
                    item.logOutput = stderr
                } else {
                    item.logOutput = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                }
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

    private enum PlanError: LocalizedError {
        case outputDirectoryMissing(URL)
        case outputDirectoryNotWritable(URL)
        case outputReservationFailed(URL, String)

        var errorDescription: String? {
            switch self {
            case .outputDirectoryMissing(let url):
                return "Save path does not exist: \(url.path(percentEncoded: false))"
            case .outputDirectoryNotWritable(let url):
                return "Save path is not writable: \(url.path(percentEncoded: false))"
            case .outputReservationFailed(let url, let reason):
                return "Could not reserve output file \(url.lastPathComponent): \(reason)"
            }
        }
    }

    private enum ReservationError: Error {
        case exists
        case failed(errno: Int32)
    }

    private func makePlan(for item: FileItem) throws -> ExecutionPlan {
        let baseDir = outputDirectory ?? item.url.deletingLastPathComponent()
        let stem = item.url.deletingPathExtension().lastPathComponent

        switch item.action {
        case .createCD:
            try validateOutputDirectory(baseDir)
            let out = try reserveUniqueURL(in: baseDir, stem: stem, ext: "chd")
            return ExecutionPlan(
                args: ["createcd", "-i", item.url.path, "-o", out.path, "-f"],
                outputURL: out,
                cleanupURLs: [out]
            )
        case .extractCD:
            try validateOutputDirectory(baseDir)
            let (outCue, outBin) = try reserveUniqueURLPair(
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

    private func validateOutputDirectory(_ dir: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw PlanError.outputDirectoryMissing(dir)
        }
        guard FileManager.default.isWritableFile(atPath: dir.path) else {
            throw PlanError.outputDirectoryNotWritable(dir)
        }
    }

    private func reserveUniqueURL(in dir: URL, stem: String, ext: String) throws -> URL {
        let candidate = dir.appendingPathComponent("\(stem).\(ext)")
        switch reserveOutputFile(at: candidate) {
        case .success:
            return candidate
        case .failure(.exists):
            break
        case .failure(.failed(let code)):
            throw PlanError.outputReservationFailed(candidate, String(cString: strerror(code)))
        }

        var i = 2
        while true {
            let next = dir.appendingPathComponent("\(stem) (\(i)).\(ext)")
            switch reserveOutputFile(at: next) {
            case .success:
                return next
            case .failure(.exists):
                i += 1
                continue
            case .failure(.failed(let code)):
                throw PlanError.outputReservationFailed(next, String(cString: strerror(code)))
            }
        }
    }

    private func reserveUniqueURLPair(
        in dir: URL,
        stem: String,
        primaryExt: String,
        secondaryExt: String
    ) throws -> (URL, URL) {
        var i = 1
        while true {
            let suffix = i == 1 ? "" : " (\(i))"
            let baseName = "\(stem)\(suffix)"
            let primary = dir.appendingPathComponent("\(baseName).\(primaryExt)")
            let secondary = dir.appendingPathComponent("\(baseName).\(secondaryExt)")

            switch reserveOutputFile(at: primary) {
            case .success:
                break
            case .failure(.exists):
                i += 1
                continue
            case .failure(.failed(let code)):
                throw PlanError.outputReservationFailed(primary, String(cString: strerror(code)))
            }

            switch reserveOutputFile(at: secondary) {
            case .success:
                return (primary, secondary)
            case .failure(.exists):
                try? FileManager.default.removeItem(at: primary)
                i += 1
                continue
            case .failure(.failed(let code)):
                try? FileManager.default.removeItem(at: primary)
                throw PlanError.outputReservationFailed(secondary, String(cString: strerror(code)))
            }
        }
    }

    private func reserveOutputFile(at url: URL) -> Result<Void, ReservationError> {
        let path = url.path(percentEncoded: false)
        let fd = path.withCString {
            open($0, O_CREAT | O_EXCL | O_WRONLY, mode_t(S_IRUSR | S_IWUSR))
        }
        guard fd >= 0 else {
            if errno == EEXIST {
                return .failure(.exists)
            }
            return .failure(.failed(errno: errno))
        }
        close(fd)
        return .success(())
    }

    private func removePlannedOutputs(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Presentation state

    func preflightIssuesForPendingItems() -> [PreflightIssue] {
        items
            .filter { isPending($0) }
            .flatMap(preflightIssues(for:))
            .sorted {
                if $0.severity != $1.severity {
                    return $0.severity > $1.severity
                }
                return $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
            }
    }

    var pendingCount: Int {
        items.filter { isPending($0) }.count
    }

    var finishedCount: Int {
        items.filter { itemIsFinished($0) }.count
    }

    var riskCount: Int {
        preflightIssuesForPendingItems().filter { $0.severity >= .caution }.count
    }

    private func preflightIssues(for item: FileItem) -> [PreflightIssue] {
        var issues: [PreflightIssue] = []

        let missing = item.references.filter { !$0.exists }
        for ref in missing {
            issues.append(
                PreflightIssue(
                    itemID: item.id,
                    fileName: item.displayName,
                    severity: .critical,
                    title: "Missing reference file",
                    detail: "\(ref.name) is referenced by the sheet but was not found next to it."
                )
            )
        }

        if item.redumpInProgress {
            issues.append(
                PreflightIssue(
                    itemID: item.id,
                    fileName: item.displayName,
                    severity: .caution,
                    title: "Disc audit still running",
                    detail: "Hunky has not finished hashing this disc yet, so Redump and structural warnings may still change."
                )
            )
        }

        for issue in item.auditIssues {
            issues.append(
                PreflightIssue(
                    itemID: item.id,
                    fileName: item.displayName,
                    severity: severity(for: issue),
                    title: issue.message,
                    detail: issue.help
                )
            )
        }

        if case .corrupted = item.redumpAggregate,
           !item.auditIssues.contains(where: {
               if case .trackCorrupted = $0.kind { return true }
               return false
           }) {
            issues.append(
                PreflightIssue(
                    itemID: item.id,
                    fileName: item.displayName,
                    severity: .critical,
                    title: "Redump corruption detected",
                    detail: "A referenced track has the right size for a known dump but a different CRC32."
                )
            )
        }

        return issues
    }

    private func severity(for issue: DiscAuditIssue) -> RiskSeverity {
        switch issue.kind {
        case .trackCorrupted, .wrongSize, .wrongTrack, .differentGame:
            return .critical
        case .sameFileReferenced, .duplicateTracks, .sectorMisaligned, .unexpectedlySmall,
             .filenameTrackMismatch, .unreferencedTrack, .cueChanged:
            return .caution
        }
    }

    private func makeRunSummary(runIDs: Set<UUID>, startedAt: Date, endedAt: Date) -> RunSummary {
        let ranItems = items.filter { runIDs.contains($0.id) }
        var succeeded = 0
        var created = 0
        var extracted = 0
        var inspected = 0
        var verified = 0
        var failed = 0
        var cancelled = 0

        for item in ranItems {
            switch item.status {
            case .done:
                succeeded += 1
                switch item.action {
                case .createCD:  created += 1
                case .extractCD: extracted += 1
                case .info:      inspected += 1
                case .verify:    verified += 1
                }
            case .failed:
                failed += 1
            case .cancelled:
                cancelled += 1
            case .idle, .running:
                break
            }
        }

        return RunSummary(
            total: ranItems.count,
            succeeded: succeeded,
            created: created,
            extracted: extracted,
            inspected: inspected,
            verified: verified,
            failed: failed,
            cancelled: cancelled,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }

    private static func combinedLog(stdout: String, stderr: String) -> String? {
        let trimmedOut = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedErr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (trimmedOut.isEmpty, trimmedErr.isEmpty) {
        case (true, true):
            return nil
        case (false, true):
            return stdout
        case (true, false):
            return stderr
        case (false, false):
            return "STDOUT:\n\(stdout)\n\nSTDERR:\n\(stderr)"
        }
    }
}
