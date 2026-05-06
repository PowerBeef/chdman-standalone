import SwiftUI

struct QueueRow: View {
    @Bindable var item: FileItem
    let isQueueRunning: Bool
    let onRemove: () -> Void
    let onShowInfo: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(iconColor)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: item.auditIssues.isEmpty ? 4 : 5) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.body)
                    Text(item.typeChip)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.18), in: Capsule())
                        .foregroundStyle(.secondary)
                    if let platform = item.identity?.platform, platform != .cdrom {
                        Text(platform.rawValue)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.18), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                if let identity = item.identity, identity.hasAnything {
                    identityLine(identity)
                }
                auditWarningStrip
                redumpLine
                if !item.references.isEmpty {
                    referencesLine
                }
                statusLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            actionPicker
                .frame(width: 130)
                .padding(.top, controlTopPadding)

            trailing
                .frame(width: 110, alignment: .trailing)
                .padding(.top, controlTopPadding)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    @ViewBuilder
    private var actionPicker: some View {
        let available = Action.defaultActions(for: item.kind)
        if available.count == 1 {
            HStack(spacing: 6) {
                Image(systemName: available[0].systemImage)
                Text(available[0].label)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        } else {
            Picker("", selection: $item.action) {
                ForEach(available) { a in
                    Label(a.label, systemImage: a.systemImage).tag(a)
                }
            }
            .labelsHidden()
            .disabled(!isItemIdle || isQueueRunning)
        }
    }

    @ViewBuilder
    private var auditWarningStrip: some View {
        let visibleIssues = Array(item.auditIssues.prefix(2))
        if !visibleIssues.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .imageScale(.small)
                    Text("Disc audit warnings")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                    if item.auditIssues.count > 1 {
                        Text("\(item.auditIssues.count)")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.16), in: Capsule())
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(visibleIssues) { issue in
                        auditIssueLine(issue)
                    }
                    if item.auditIssues.count > visibleIssues.count {
                        Text("+\(item.auditIssues.count - visibleIssues.count) more warnings")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.orange.opacity(0.24), lineWidth: 1)
            )
            .padding(.top, 1)
            .padding(.bottom, 2)
        }
    }

    private func auditIssueLine(_ issue: DiscAuditIssue) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "smallcircle.filled.circle")
                .foregroundStyle(.orange)
                .font(.system(size: 6, weight: .semibold))
                .frame(width: 10)
            Text(issue.message)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption2)
        .help(issue.help)
    }

    @ViewBuilder
    private var redumpLine: some View {
        switch item.redumpAggregate {
        case .notApplicable:
            EmptyView()
        case .unavailable(let platform):
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                Text("No \(platform.rawValue) Redump DAT bundled")
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
            .help("Hunky recognized this platform, but the app bundle does not include a matching offline Redump DAT yet.")
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small).scaleEffect(0.7).frame(width: 14, height: 14)
                Text("Verifying against Redump…")
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
        case .verified(let identity):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .imageScale(.small)
                Text("Redump match · ")
                    .foregroundStyle(.secondary)
                + Text(redumpLabel(for: identity))
                    .foregroundStyle(.primary)
            }
            .font(.caption2)
            .help("All track CRC32s match the Redump entry for this game.")
        case .partial(let identities):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                Text(
                    identities.count == 1
                        ? "Partial Redump match · \(redumpLabel(for: identities[0]))"
                        : "Partial Redump match"
                )
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
        case .corrupted:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .imageScale(.small)
                Text("Looks corrupted — file size matches a known dump but CRC32 differs")
                    .foregroundStyle(.orange)
            }
            .font(.caption2)
            .help("At least one referenced track has the right size but a wrong CRC. Likely a bad/incomplete download.")
        case .unknown:
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                Text("Not in Redump database")
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
            .help("This dump's CRC32 isn't recognized — could be a different region/revision, a homebrew, or an unverified rip.")
        }
    }

    @ViewBuilder
    private func identityLine(_ identity: DiscInspector.Identity) -> some View {
        let parts: [String] = [
            identity.bestTitle,
            identity.gameID
        ].compactMap { $0 }
        if !parts.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "gamecontroller")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                Text(parts.joined(separator: " · "))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
            }
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
                Text("· \(item.missingReferenceCount) missing")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
                    .help("chdman will likely fail unless these files are placed next to the sheet.")
            }
        }
    }

    private let maxReferenceChips = 3

    private func referenceChip(_ ref: DiscSheet.Reference) -> some View {
        HStack(spacing: 3) {
            Image(systemName: ref.exists ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ref.exists ? .green : .orange)
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
            Text("Ready")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .running(let p):
            ProgressView(value: p)
                .progressViewStyle(.linear)
                .tint(.accentColor)
        case .done:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(doneText).foregroundStyle(.secondary)
            }
            .font(.caption)
        case .failed(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(msg)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        case .cancelled:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                Text("Cancelled").foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch item.status {
        case .running:
            ProgressView().controlSize(.small)
        case .done:
            HStack(spacing: 6) {
                if item.action == .info {
                    Button("View") { onShowInfo() }
                        .buttonStyle(.borderless)
                } else if let out = item.outputURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([out])
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
                }
                removeButton
            }
        case .failed, .cancelled, .idle:
            removeButton
        }
    }

    private var removeButton: some View {
        Button {
            onRemove()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .disabled(isItemRunning)
        .help("Remove from queue")
    }

    private var iconName: String {
        switch item.kind {
        case .cdImage: return "opticaldisc"
        case .chd:     return "shippingbox"
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .done:     return .green
        case .failed:   return .orange
        case .running:  return .accentColor
        default:        return .secondary
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

    private var controlTopPadding: CGFloat {
        item.auditIssues.isEmpty ? 26 : 76
    }

    private func redumpLabel(for identity: DiscAudit.RedumpIdentity) -> String {
        "\(RedumpDatabase.platformDisplayName(for: identity.platformKey)) · \(identity.gameName)"
    }

    private var doneText: String {
        if case .done(let msg?) = item.status { return msg }
        switch item.action {
        case .createCD:  return "Created"
        case .extractCD: return "Extracted"
        case .info:      return "Ready to view"
        case .verify:    return "Verified"
        }
    }
}
