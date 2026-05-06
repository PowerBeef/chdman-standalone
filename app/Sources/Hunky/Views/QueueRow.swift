import AppKit
import SwiftUI

struct QueueRow: View {
    @Bindable var item: FileItem
    let isQueueRunning: Bool
    let onRemove: () -> Void
    let onRetry: () -> Void
    let onShowInfo: () -> Void
    let onShowLog: () -> Void

    @State private var isWarningsExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            discColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            healthColumn
                .frame(width: 190, alignment: .leading)

            actionColumn
                .frame(width: 130, alignment: .leading)

            resultColumn
                .frame(width: 150, alignment: .trailing)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(HunkyTheme.raisedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(rowStrokeColor, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var discColumn: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.title3)
                .frame(width: 24)
                .foregroundStyle(iconColor)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.body.weight(.medium))
                    typeChip(item.typeChip, tint: .secondary)
                    if let platform = item.identity?.platform, platform != .cdrom {
                        typeChip(platform.rawValue, tint: HunkyTheme.retroBlue)
                    }
                }

                if let identity = item.identity, identity.hasAnything {
                    identityLine(identity)
                }

                if !item.references.isEmpty {
                    referencesLine
                } else {
                    Text(item.kind == .chd ? "CHD source" : "Single image")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var healthColumn: some View {
        VStack(alignment: .leading, spacing: 7) {
            columnLabel("Health")
            redumpLine
            warningSummary
        }
    }

    private var actionColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            columnLabel("Action")
            actionPicker
        }
    }

    private var resultColumn: some View {
        VStack(alignment: .trailing, spacing: 7) {
            statusLine
            resultButtons
        }
    }

    @ViewBuilder
    private var actionPicker: some View {
        let available = Action.defaultActions(for: item.kind)
        if available.count == 1 {
            Label(available[0].label, systemImage: available[0].systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
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

    @ViewBuilder
    private var warningSummary: some View {
        if item.auditIssues.isEmpty && item.missingReferenceCount == 0 {
            Label("No warnings", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(HunkyTheme.verifiedGreen)
        } else {
            VStack(alignment: .leading, spacing: 5) {
                Button {
                    isWarningsExpanded.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .imageScale(.small)
                        Text(warningTitle)
                            .lineLimit(1)
                        Image(systemName: isWarningsExpanded ? "chevron.up" : "chevron.down")
                            .imageScale(.small)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(HunkyTheme.amber)
                }
                .buttonStyle(.plain)
                .help("Show disc audit warnings")
                .accessibilityLabel("\(warningTitle) for \(item.displayName)")

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
                    .foregroundStyle(HunkyTheme.amber)
                    .padding(.leading, 2)
                }
            }
        }
    }

    private var warningTitle: String {
        let count = item.auditIssues.count + (item.missingReferenceCount > 0 ? 1 : 0)
        if count == 1 { return "1 warning" }
        return "\(count) warnings"
    }

    private func auditIssueLine(_ issue: DiscAuditIssue) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Text("-")
            Text(issue.message)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .help(issue.help)
    }

    @ViewBuilder
    private var redumpLine: some View {
        switch item.redumpAggregate {
        case .notApplicable:
            Text(item.kind == .chd ? "No sheet audit" : "Local checks only")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .unavailable(let platform):
            Label("No \(platform.rawValue) DAT", systemImage: "questionmark.circle")
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
                .foregroundStyle(HunkyTheme.verifiedGreen)
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
                .foregroundStyle(HunkyTheme.amber)
                .help("At least one referenced track has the right size but a wrong CRC. Likely a bad or incomplete download.")
        case .unknown:
            Label("Not in Redump", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("This dump's CRC32 is not recognized. It could be a different region, homebrew, or an unverified rip.")
        }
    }

    @ViewBuilder
    private func identityLine(_ identity: DiscInspector.Identity) -> some View {
        let parts: [String] = [
            identity.bestTitle,
            identity.gameID
        ].compactMap { $0 }
        if !parts.isEmpty {
            Label(parts.joined(separator: " - "), systemImage: "gamecontroller")
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var referencesLine: some View {
        let visible = item.references.prefix(maxReferenceChips)
        let overflow = item.references.count - visible.count
        HStack(spacing: 6) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, ref in
                referenceChip(ref)
            }
            if overflow > 0 {
                Text("+\(overflow) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if item.missingReferenceCount > 0 {
                Text("\(item.missingReferenceCount) missing")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(HunkyTheme.amber)
                    .help("chdman will likely fail unless these files are placed next to the sheet.")
            }
        }
    }

    private let maxReferenceChips = 2

    private func referenceChip(_ ref: DiscSheet.Reference) -> some View {
        HStack(spacing: 3) {
            Image(systemName: ref.exists ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ref.exists ? HunkyTheme.verifiedGreen : HunkyTheme.amber)
                .imageScale(.small)
            Text(ref.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(ref.exists ? .secondary : .primary)
        }
        .font(.caption2)
        .help(ref.exists ? ref.url.path(percentEncoded: false) : "Missing: \(ref.url.path(percentEncoded: false))")
    }

    @ViewBuilder
    private var statusLine: some View {
        switch item.status {
        case .idle:
            Label("Ready", systemImage: "circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .running(let progress):
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(HunkyTheme.retroBlue)
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(HunkyTheme.retroBlue)
                    .frame(width: 128)
                    .accessibilityLabel("Progress for \(item.displayName)")
                    .accessibilityValue("\(Int((progress * 100).rounded())) percent")
            }
        case .done:
            Label(doneText, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(HunkyTheme.verifiedGreen)
                .lineLimit(1)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(HunkyTheme.failureRed)
                .lineLimit(2)
                .truncationMode(.tail)
        case .cancelled:
            Label("Cancelled", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var resultButtons: some View {
        switch item.status {
        case .running:
            EmptyView()
        case .done:
            HStack(spacing: 6) {
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
            HStack(spacing: 6) {
                iconButton("Copy error", systemImage: "doc.on.doc", action: copyLog)
                iconButton("View log", systemImage: "terminal", action: onShowLog)
                iconButton("Retry", systemImage: "arrow.clockwise", action: onRetry)
                removeButton
            }
        case .cancelled:
            HStack(spacing: 6) {
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
            .foregroundStyle(.secondary)
            .disabled(isItemRunning)
    }

    private func columnLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func typeChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }

    private var iconName: String {
        switch item.kind {
        case .cdImage: return "opticaldisc"
        case .chd:     return "shippingbox"
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .done:     return HunkyTheme.verifiedGreen
        case .failed:   return HunkyTheme.failureRed
        case .running:  return HunkyTheme.retroBlue
        default:        return .secondary
        }
    }

    private var rowStrokeColor: Color {
        switch item.status {
        case .failed:
            return HunkyTheme.failureRed.opacity(0.45)
        case .running:
            return HunkyTheme.retroBlue.opacity(0.45)
        default:
            return HunkyTheme.hairline.opacity(0.65)
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

    private func redumpLabel(for identity: DiscAudit.RedumpIdentity) -> String {
        "\(RedumpDatabase.platformDisplayName(for: identity.platformKey)) - \(identity.gameName)"
    }

    private var doneText: String {
        if case .done(let message?) = item.status { return message }
        switch item.action {
        case .createCD:  return "Created"
        case .extractCD: return "Extracted"
        case .info:      return "Info ready"
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
