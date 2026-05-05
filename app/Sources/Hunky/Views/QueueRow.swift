import SwiftUI

struct QueueRow: View {
    @Bindable var item: FileItem
    let isQueueRunning: Bool
    let onRemove: () -> Void
    let onShowInfo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 4) {
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
                redumpLine
                if !item.references.isEmpty {
                    referencesLine
                }
                statusLine
            }

            Spacer(minLength: 8)

            actionPicker
                .frame(width: 130)

            trailing
                .frame(width: 110, alignment: .trailing)
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
    private var redumpLine: some View {
        switch item.redumpAggregate {
        case .notApplicable:
            EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small).scaleEffect(0.7).frame(width: 14, height: 14)
                Text("Verifying against Redump…")
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
        case .wrongTrack(let expected, let found, let gameName):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .imageScale(.small)
                Text("Track \(expected) appears to be Track \(found)")
                    .foregroundStyle(.orange)
            }
            .font(.caption2)
            .help("This file matches Redump's Track \(found) for \(gameName), but the cue lists it as Track \(expected).")
        case .duplicateTracks(let first, let second):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .imageScale(.small)
                Text("Tracks \(first) and \(second) are identical")
                    .foregroundStyle(.orange)
            }
            .font(.caption2)
            .help("Two cue tracks have the same size and CRC32. This usually means one track was copied over another.")
        case .verified(let game):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .imageScale(.small)
                Text("Redump match · ")
                    .foregroundStyle(.secondary)
                + Text(game)
                    .foregroundStyle(.primary)
            }
            .font(.caption2)
            .help("All track CRC32s match the Redump entry for this game.")
        case .partial(let games):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                Text(games.count == 1 ? "Partial Redump match · \(games[0])" : "Partial Redump match")
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

    private func referenceChip(_ ref: CueSheet.Reference) -> some View {
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
