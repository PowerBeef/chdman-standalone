import AppKit
import SwiftUI

// MARK: - Column geometry shared between header and row

enum QueueColumns {
    static let auditWidth: CGFloat = 178
    static let actionWidth: CGFloat = 84
    static let statusWidth: CGFloat = 140
    static let columnSpacing: CGFloat = 14
    static let rowVerticalPadding: CGFloat = 12
    static let rowHorizontalPadding: CGFloat = 16
}

// MARK: - Sticky column header

struct QueueColumnHeader: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: QueueColumns.columnSpacing) {
            label("Disc")
                .frame(maxWidth: .infinity, alignment: .leading)
            label("Audit")
                .frame(width: QueueColumns.auditWidth, alignment: .leading)
            label("Action")
                .frame(width: QueueColumns.actionWidth, alignment: .leading)
            label("Status")
                .frame(width: QueueColumns.statusWidth, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, QueueColumns.rowHorizontalPadding)
        .background(
            HunkyTheme.surface
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(HunkyTheme.hairline)
                        .frame(height: 1)
                }
        )
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Row

struct QueueRow: View {
    @Bindable var item: FileItem
    let isQueueRunning: Bool
    let onRemove: () -> Void
    let onRetry: () -> Void
    let onShowInfo: () -> Void
    let onShowLog: () -> Void

    @State private var isWarningsExpanded = false
    @State private var isRefsExpanded = false
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: QueueColumns.columnSpacing) {
            discColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            auditColumn
                .frame(width: QueueColumns.auditWidth, alignment: .leading)

            actionColumn
                .frame(width: QueueColumns.actionWidth, alignment: .leading)

            statusColumn
                .frame(width: QueueColumns.statusWidth, alignment: .leading)
        }
        .padding(.vertical, QueueColumns.rowVerticalPadding)
        .padding(.horizontal, QueueColumns.rowHorizontalPadding)
        .background(rowBackground)
        .animation(reduceMotion ? nil : HunkyMotion.snap, value: statusKey)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Disc column

    private var discColumn: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.title3)
                .frame(width: 22)
                .foregroundStyle(iconColor)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                discChipsLine

                if let identity = item.identity, identity.hasAnything {
                    identityLine(identity)
                }
            }
        }
    }

    private var discChipsLine: some View {
        HStack(spacing: 6) {
            typeChip(item.typeChip, tint: .secondary)
            if let platform = item.identity?.platform, platform != .cdrom {
                typeChip(platform.rawValue, tint: .accentColor)
            }
        }
    }

    @ViewBuilder
    private func identityLine(_ identity: DiscInspector.Identity) -> some View {
        let parts: [String] = [identity.bestTitle, identity.gameID].compactMap { $0 }
        if !parts.isEmpty {
            Label(parts.joined(separator: " · "), systemImage: "gamecontroller")
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
                .font(.caption)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func typeChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel(text)
    }

    // MARK: - Audit column

    private var auditColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            redumpLine
            if !item.references.isEmpty {
                referencesIndicator
            }
            if hasWarnings {
                warningSummary
            }
        }
    }

    private var hasWarnings: Bool {
        !item.auditIssues.isEmpty || item.missingReferenceCount > 0
    }

    @ViewBuilder
    private var referencesIndicator: some View {
        let total = item.references.count
        let missing = item.missingReferenceCount
        let isOK = missing == 0
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(reduceMotion ? nil : HunkyMotion.snap) {
                    isRefsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isOK ? "checkmark.circle" : "exclamationmark.triangle.fill")
                        .imageScale(.small)
                    Text(referencesSummaryText(total: total, missing: missing))
                        .lineLimit(1)
                    Image(systemName: isRefsExpanded ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                }
                .font(.caption)
                .foregroundStyle(isOK ? .secondary : HunkyTheme.severityCaution)
            }
            .buttonStyle(.plain)
            .help(isOK
                ? "All referenced files are present next to the sheet."
                : "Some referenced files are missing or the wrong size. chdman will likely fail.")
            .accessibilityLabel(referencesAccessibilityLabel(total: total, missing: missing))

            if isRefsExpanded {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(item.references.enumerated()), id: \.offset) { _, ref in
                        referenceLine(ref)
                    }
                }
                .padding(.leading, 2)
            }
        }
    }

    private func referencesSummaryText(total: Int, missing: Int) -> String {
        let base = "\(total) reference\(total == 1 ? "" : "s")"
        if missing == 0 { return base }
        return "\(base) · \(missing) missing"
    }

    private func referencesAccessibilityLabel(total: Int, missing: Int) -> String {
        if missing == 0 {
            return "\(total) referenced file\(total == 1 ? "" : "s"), all present"
        }
        return "\(total) referenced file\(total == 1 ? "" : "s"), \(missing) missing"
    }

    private func referenceLine(_ ref: DiscSheet.Reference) -> some View {
        HStack(spacing: 5) {
            Image(systemName: ref.exists ? "circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ref.exists ? HunkyTheme.inkTertiary : HunkyTheme.severityCaution)
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(ref.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(ref.exists ? .secondary : .primary)
        }
        .font(.caption2)
        .help(ref.exists ? ref.url.path(percentEncoded: false) : "Missing: \(ref.url.path(percentEncoded: false))")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ref.exists ? "Referenced file: \(ref.name)" : "Referenced file missing: \(ref.name)")
    }

    @ViewBuilder
    private var redumpLine: some View {
        switch item.redumpAggregate {
        case .notApplicable:
            Text(item.kind == .chd ? "No sheet audit" : "No track audit")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .unavailable(let platform):
            Label("\(platform.rawValue) catalog not bundled", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Hunky recognized this platform, but the app bundle does not include a matching offline Redump DAT yet.")
        case .checking:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .frame(width: 14, height: 14)
                Text("Checking Redump")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        case .verified(let identity):
            Label(redumpLabel(for: identity), systemImage: "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(HunkyTheme.severityVerified)
                .lineLimit(2)
                .help("All track CRC32s match the Redump entry for this game.")
        case .partial(let identities):
            Label(
                identities.count == 1 ? "Partial: \(redumpLabel(for: identities[0]))" : "Partial Redump match",
                systemImage: "checkmark.seal"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        case .corrupted:
            Label("Redump mismatch", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(HunkyTheme.severityCaution)
                .help("At least one referenced track has the right size but a wrong CRC. Likely a bad or incomplete download.")
        case .unknown:
            Label("Not in Redump", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("This dump's CRC32 is not recognized. It could be a different region, homebrew, or an unverified rip.")
        }
    }

    @ViewBuilder
    private var warningSummary: some View {
        let totalCount = item.auditIssues.count + (item.missingReferenceCount > 0 ? 1 : 0)
        VStack(alignment: .leading, spacing: 5) {
            Button {
                withAnimation(reduceMotion ? nil : HunkyMotion.snap) {
                    isWarningsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .imageScale(.small)
                    Text(warningTitle(totalCount))
                        .lineLimit(1)
                    Image(systemName: isWarningsExpanded ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(HunkyTheme.severityCaution)
            }
            .buttonStyle(.plain)
            .help("Show disc audit warnings")
            .accessibilityLabel("\(warningTitle(totalCount)) for \(item.displayName)")

            if isWarningsExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if item.missingReferenceCount > 0 {
                        Text("\(item.missingReferenceCount) referenced file\(item.missingReferenceCount == 1 ? "" : "s") missing")
                            .help("chdman will likely fail unless these files are placed next to the sheet.")
                    }
                    ForEach(item.auditIssues.prefix(4)) { issue in
                        auditIssueLine(issue)
                    }
                    if item.auditIssues.count > 4 {
                        Text("+\(item.auditIssues.count - 4) more")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption2)
                .foregroundStyle(HunkyTheme.severityCaution)
                .padding(.leading, 2)
            }
        }
    }

    private func warningTitle(_ count: Int) -> String {
        count == 1 ? "1 warning" : "\(count) warnings"
    }

    private func auditIssueLine(_ issue: DiscAuditIssue) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Text("·")
            Text(issue.message)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .help(issue.help)
    }

    // MARK: - Action column

    private var actionColumn: some View {
        Group {
            let available = Action.defaultActions(for: item.kind)
            if available.count == 1 {
                Label(available[0].label, systemImage: available[0].systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                Picker("Action", selection: $item.action) {
                    ForEach(available) { action in
                        Label(action.label, systemImage: action.systemImage).tag(action)
                    }
                }
                .labelsHidden()
                .disabled(!isItemIdle || isQueueRunning)
                .accessibilityLabel("Action for \(item.displayName)")
            }
        }
    }

    // MARK: - Status column

    private var statusColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            statusLine
            if hasResultButtons {
                resultButtons
                    .opacity(isHovering ? 1.0 : 0.55)
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch item.status {
        case .idle:
            Label("Ready", systemImage: "circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .running(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.accentColor)
                progressBar(value: progress)
                    .frame(width: 124, height: 6)
                    .accessibilityLabel("Progress for \(item.displayName)")
                    .accessibilityValue("\(Int((progress * 100).rounded())) percent")
            }
        case .done:
            Label(doneText, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(HunkyTheme.severityVerified)
                .lineLimit(1)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(HunkyTheme.severityCritical)
                .lineLimit(2)
                .truncationMode(.tail)
        case .cancelled:
            Label("Cancelled", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var hasResultButtons: Bool {
        switch item.status {
        case .running: return false
        case .done, .failed, .cancelled, .idle: return true
        }
    }

    @ViewBuilder
    private var resultButtons: some View {
        switch item.status {
        case .running:
            EmptyView()
        case .done:
            HStack(spacing: 4) {
                if item.action == .info {
                    iconButton("View info", systemImage: "doc.text.magnifyingglass", action: onShowInfo)
                } else if let outputURL = item.outputURL {
                    iconButton("Show in Finder", systemImage: "folder", action: {
                        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                    })
                }
                if item.logOutput != nil {
                    iconButton("View log", systemImage: "terminal", action: onShowLog)
                }
                removeButton
            }
        case .failed:
            HStack(spacing: 4) {
                iconButton("Copy error", systemImage: "doc.on.doc", action: copyLog)
                iconButton("View log", systemImage: "terminal", action: onShowLog)
                iconButton("Retry", systemImage: "arrow.clockwise", action: onRetry)
                removeButton
            }
        case .cancelled:
            HStack(spacing: 4) {
                iconButton("Retry", systemImage: "arrow.clockwise", action: onRetry)
                removeButton
            }
        case .idle:
            removeButton
        }
    }

    private func iconButton(_ label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .help(label)
        .accessibilityLabel(label)
    }

    private var removeButton: some View {
        iconButton("Remove from queue", systemImage: "xmark.circle.fill", action: onRemove)
            .foregroundStyle(HunkyTheme.inkTertiary)
            .disabled(isItemRunning)
    }

    // MARK: - Custom progress bar with shimmer

    @ViewBuilder
    private func progressBar(value: Double) -> some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let clamped = max(0, min(1, value))
            let fillWidth = totalWidth * CGFloat(clamped)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(nsColor: .quaternaryLabelColor))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: fillWidth)
                    .overlay(alignment: .leading) {
                        if !reduceMotion && fillWidth > 24 {
                            shimmerBand(fillWidth: fillWidth)
                                .frame(width: fillWidth)
                                .clipShape(Capsule())
                        }
                    }
            }
        }
    }

    private func shimmerBand(fillWidth: CGFloat) -> some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: HunkyMotion.shimmerPeriod)) / HunkyMotion.shimmerPeriod
            let bandW: CGFloat = 60
            let x = -bandW + (fillWidth + bandW) * CGFloat(phase)
            Capsule()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.0), location: 0.0),
                            .init(color: .white.opacity(0.32), location: 0.5),
                            .init(color: .white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: bandW)
                .offset(x: x)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Row background and helpers

    private var rowBackground: some View {
        Group {
            switch item.status {
            case .running:
                HunkyTheme.surfaceMuted.opacity(0.5)
            case .failed:
                HunkyTheme.severityCritical.opacity(0.06)
            default:
                Color.clear
            }
        }
    }

    private var iconName: String {
        switch item.kind {
        case .cdImage: return "opticaldisc"
        case .chd:     return "shippingbox"
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .done:    return HunkyTheme.severityVerified
        case .failed:  return HunkyTheme.severityCritical
        case .running: return Color.accentColor
        default:       return HunkyTheme.inkTertiary
        }
    }

    private var isItemRunning: Bool {
        if case .running = item.status { return true }
        return false
    }

    private var isItemIdle: Bool {
        if case .idle = item.status { return true }
        return false
    }

    /// Status discriminant used for animation diffing — `FileItem.Status` is
    /// not Equatable, so we reduce it to a string key.
    private var statusKey: String {
        switch item.status {
        case .idle:                return "idle"
        case .running(let p):      return "running:\(Int(p * 100))"
        case .done(let m):         return "done:\(m ?? "")"
        case .failed(let m):       return "failed:\(m)"
        case .cancelled:           return "cancelled"
        }
    }

    private func redumpLabel(for identity: DiscAudit.RedumpIdentity) -> String {
        "\(RedumpDatabase.platformDisplayName(for: identity.platformKey)) · \(identity.gameName)"
    }

    private var doneText: String {
        if case .done(let message?) = item.status { return message }
        switch item.action {
        case .createCD:  return "Created"
        case .extractCD: return "Extracted"
        case .info:      return "Inspected"
        case .verify:    return "Verified"
        }
    }

    private func copyLog() {
        let text: String
        if let log = item.logOutput, !log.isEmpty {
            text = log
        } else if case .failed(let message) = item.status {
            text = message
        } else {
            text = ""
        }
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
