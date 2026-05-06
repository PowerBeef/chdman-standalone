import AppKit
import SwiftUI

// MARK: - Column geometry shared between header and row
//
// Five columns total: a 38pt leading lane that holds the 3pt platform
// spine flush-left, then disc / audit / action / status. Spine spans the
// row's full vertical via overlay; the cells live inside an inner HStack.

enum QueueColumns {
    /// Total leading column width (spine 3pt + breathing room).
    static let spineLaneWidth: CGFloat = 38
    /// Width of the spine bar itself.
    static let spineWidth: CGFloat = 3
    static let auditWidth: CGFloat = 200
    static let actionWidth: CGFloat = 96
    static let statusWidth: CGFloat = 156
    static let columnSpacing: CGFloat = 14
    static let rowVerticalPadding: CGFloat = 12
    static let rowTrailingPadding: CGFloat = 16
}

// MARK: - Column header

struct QueueColumnHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            // Spine lane spacer
            Spacer().frame(width: QueueColumns.spineLaneWidth)

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
            .padding(.vertical, 8)
            .padding(.trailing, QueueColumns.rowTrailingPadding)
        }
        .background(
            HunkyTheme.surfaceSunken
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(HunkyTheme.hairline)
                        .frame(height: 1)
                }
        )
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .medium))
            .tracking(0.5)
            .foregroundStyle(HunkyTheme.inkTertiary)
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
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Spine lane (38pt). Spine is rendered via overlay so it spans
            // the full row height regardless of cell content.
            Spacer().frame(width: QueueColumns.spineLaneWidth)

            HStack(alignment: .top, spacing: QueueColumns.columnSpacing) {
                discCell
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                auditCell
                    .frame(width: QueueColumns.auditWidth, alignment: .leading)

                actionCell
                    .frame(width: QueueColumns.actionWidth, alignment: .leading)

                statusCell
                    .frame(width: QueueColumns.statusWidth, alignment: .leading)
            }
            .padding(.vertical, QueueColumns.rowVerticalPadding)
            .padding(.trailing, QueueColumns.rowTrailingPadding)
        }
        .background(rowBackground)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(spineColor)
                .frame(width: QueueColumns.spineWidth)
        }
        .animation(reduceMotion ? nil : HunkyMotion.snap, value: statusKey)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Disc cell

    private var discCell: some View {
        HStack(alignment: .top, spacing: 10) {
            DiscIcon(item: item)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HunkyTheme.inkPrimary)

                discChipsLine

                if let meta = telemetryMeta() {
                    HStack(spacing: 12) {
                        ForEach(Array(meta.enumerated()), id: \.offset) { _, pair in
                            HStack(spacing: 4) {
                                Text(pair.key)
                                    .foregroundStyle(HunkyTheme.inkQuaternary)
                                Text(pair.value)
                                    .foregroundStyle(HunkyTheme.inkTertiary)
                            }
                        }
                    }
                    .font(HunkyType.mono)
                }
            }
        }
        .padding(.leading, 4)
    }

    private var discChipsLine: some View {
        HStack(spacing: 5) {
            FormatChip(text: item.typeChip)
            if let platform = item.identity?.platform, platform != .cdrom {
                PlatformChip(platform: platform)
            }
            if let identity = item.identity?.bestTitle {
                Text(identity)
                    .font(.system(size: 11))
                    .foregroundStyle(HunkyTheme.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 2)
            }
        }
    }

    private func telemetryMeta() -> [(key: String, value: String)]? {
        var pairs: [(String, String)] = []
        if let size = item.formattedTotalSize { pairs.append(("size", size)) }
        if let crc = item.primaryCRC { pairs.append(("crc", crc)) }
        return pairs.isEmpty ? nil : pairs
    }

    // MARK: - Audit cell

    private var auditCell: some View {
        VStack(alignment: .leading, spacing: 6) {
            auditLine
            if !item.references.isEmpty {
                refsIndicator
            }
        }
    }

    @ViewBuilder
    private var auditLine: some View {
        let style = auditStyle()
        HStack(alignment: .top, spacing: 6) {
            if let icon = style.icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(style.iconColor)
                    .frame(width: 13)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(style.title)
                    .font(.system(size: 11.5, weight: style.titleWeight))
                    .foregroundStyle(style.titleColor)
                    .fixedSize(horizontal: false, vertical: true)
                if let meta = style.meta {
                    Text(meta)
                        .font(HunkyType.mono)
                        .foregroundStyle(HunkyTheme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private struct AuditStyle {
        let icon: String?
        let iconColor: Color
        let title: String
        let titleColor: Color
        let titleWeight: Font.Weight
        let meta: String?
    }

    private func auditStyle() -> AuditStyle {
        switch item.redumpAggregate {
        case .verified(let identity):
            let platformName = RedumpDatabase.platformDisplayName(for: identity.platformKey)
            return AuditStyle(
                icon: "checkmark.seal.fill",
                iconColor: HunkyTheme.redump,
                title: "\(platformName) · \(identity.gameName)",
                titleColor: HunkyTheme.redump,
                titleWeight: .medium,
                meta: "Redump · CRC match"
            )
        case .partial(let identities):
            let label = identities.count == 1
                ? "\(RedumpDatabase.platformDisplayName(for: identities[0].platformKey)) · \(identities[0].gameName)"
                : "Partial Redump match"
            return AuditStyle(
                icon: "checkmark.circle",
                iconColor: HunkyTheme.inkSecondary,
                title: label,
                titleColor: HunkyTheme.inkPrimary,
                titleWeight: .regular,
                meta: "Redump · partial match"
            )
        case .corrupted:
            return AuditStyle(
                icon: "exclamationmark.triangle.fill",
                iconColor: HunkyTheme.severityCaution,
                title: "Track CRC mismatch",
                titleColor: HunkyTheme.severityCaution,
                titleWeight: .medium,
                meta: corruptedMetaLine()
            )
        case .unknown:
            return AuditStyle(
                icon: "questionmark.circle",
                iconColor: HunkyTheme.inkTertiary,
                title: "Not in Redump",
                titleColor: HunkyTheme.inkPrimary,
                titleWeight: .regular,
                meta: "unrecognized"
            )
        case .unavailable(let platform):
            return AuditStyle(
                icon: "questionmark.circle",
                iconColor: HunkyTheme.inkTertiary,
                title: "\(platform.rawValue) catalog not bundled",
                titleColor: HunkyTheme.inkPrimary,
                titleWeight: .regular,
                meta: "no offline DAT"
            )
        case .checking:
            return AuditStyle(
                icon: "arrow.triangle.2.circlepath",
                iconColor: HunkyTheme.inkTertiary,
                title: "Checking Redump",
                titleColor: HunkyTheme.inkSecondary,
                titleWeight: .regular,
                meta: "hashing references…"
            )
        case .notApplicable:
            return AuditStyle(
                icon: nil,
                iconColor: .clear,
                title: item.kind == .chd ? "Sealed archive" : "No track audit",
                titleColor: HunkyTheme.inkSecondary,
                titleWeight: .regular,
                meta: item.kind == .chd ? "no track audit until extracted" : nil
            )
        }
    }

    private func corruptedMetaLine() -> String {
        // We don't carry the *expected* CRC in the enum — surface what we know:
        // the bin's filename and a 4-char prefix of its actual CRC.
        for ref in item.references {
            if case .sizeMatchedButCRCMismatch = item.redumpStatuses[ref.url],
               let fp = item.referenceFingerprints[ref.url] {
                let got = String(format: "%08x", fp.crc32)
                return "size match · got \(got.prefix(4))"
            }
        }
        return "size matched · wrong CRC"
    }

    @ViewBuilder
    private var refsIndicator: some View {
        let total = item.references.count
        let missing = item.missingReferenceCount
        let isOK = missing == 0
        Button {
            withAnimation(reduceMotion ? nil : HunkyMotion.snap) {
                isWarningsExpanded.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isOK ? "checkmark.circle" : "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                Text(refsSummaryText(total: total, missing: missing))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .opacity(0.5)
                    .rotationEffect(.degrees(isWarningsExpanded ? 90 : 0))
            }
            .font(.system(size: 10.5))
            .foregroundStyle(isOK ? HunkyTheme.inkTertiary : HunkyTheme.severityCaution)
        }
        .buttonStyle(.plain)
        .help(isOK ? "All referenced files are present." : "Some referenced files are missing or wrong size.")

        if isWarningsExpanded {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(item.references.enumerated()), id: \.offset) { _, ref in
                    HStack(spacing: 5) {
                        Image(systemName: ref.exists ? "circle.fill" : "exclamationmark.triangle.fill")
                            .imageScale(.small)
                            .foregroundStyle(ref.exists ? HunkyTheme.inkTertiary : HunkyTheme.severityCaution)
                            .accessibilityHidden(true)
                        Text(ref.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(ref.exists ? HunkyTheme.inkTertiary : HunkyTheme.inkPrimary)
                    }
                    .font(.system(size: 10.5))
                    .help(ref.exists ? ref.url.path(percentEncoded: false) : "Missing: \(ref.url.path(percentEncoded: false))")
                }
            }
            .padding(.leading, 2)
            .padding(.top, 2)
        }
    }

    private func refsSummaryText(total: Int, missing: Int) -> String {
        let base = "\(total) reference\(total == 1 ? "" : "s")"
        if missing == 0 { return base }
        return "\(base) · \(missing) missing"
    }

    // MARK: - Action cell

    private var actionCell: some View {
        Group {
            let available = Action.defaultActions(for: item.kind)
            if available.count == 1 {
                ActionPill(action: available[0], armed: true, dimmed: !isItemIdle)
            } else {
                Menu {
                    ForEach(available) { a in
                        Button {
                            item.action = a
                        } label: {
                            Label(a.label, systemImage: a.systemImage)
                        }
                    }
                } label: {
                    ActionPill(action: item.action, armed: armedAction(item.action), dimmed: !isItemIdle, hasChevron: true)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .disabled(!isItemIdle || isQueueRunning)
                .accessibilityLabel("Action for \(item.displayName)")
            }
        }
    }

    private func armedAction(_ action: Action) -> Bool {
        switch action {
        case .createCD, .extractCD: return true
        case .info, .verify:        return false
        }
    }

    // MARK: - Status cell

    private var statusCell: some View {
        VStack(alignment: .leading, spacing: 6) {
            statusLine
            if hasResultButtons {
                resultButtons
                    .opacity(isHovering ? 1.0 : 0.6)
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch item.status {
        case .idle:
            HStack(spacing: 6) {
                Image(systemName: "circle")
                    .font(.system(size: 11))
                Text("Ready")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(HunkyTheme.inkSecondary)
        case .running(let progress):
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(HunkyTheme.accent)
                }
                progressBar(value: progress)
                    .frame(height: 5)
            }
            .accessibilityLabel("Progress for \(item.displayName)")
            .accessibilityValue("\(Int((progress * 100).rounded())) percent")
        case .done:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text(doneText)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(HunkyTheme.severityVerified)
            .lineLimit(1)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 11))
                    Text("Failed")
                        .lineLimit(1)
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(HunkyTheme.severityCritical)
                Text(message)
                    .font(HunkyType.mono)
                    .foregroundStyle(HunkyTheme.severityCritical.opacity(0.85))
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        case .cancelled:
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 11))
                Text("Cancelled")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(HunkyTheme.inkTertiary)
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
                .font(.system(size: 11))
                .frame(width: 22, height: 22)
                .foregroundStyle(HunkyTheme.inkTertiary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private var removeButton: some View {
        iconButton("Remove from queue", systemImage: "xmark", action: onRemove)
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
                    .fill(HunkyTheme.surfaceSunken)
                Capsule()
                    .fill(HunkyTheme.accent)
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

    // MARK: - Spine + background

    private var spineColor: Color {
        guard let platform = item.identity?.platform else {
            return HunkyTheme.platformCDROM
        }
        switch platform {
        case .ps1:       return HunkyTheme.platformPSX
        case .saturn:    return HunkyTheme.platformSaturn
        case .dreamcast: return HunkyTheme.platformDreamcast
        case .cdrom:     return HunkyTheme.platformCDROM
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        ZStack {
            // Row resting fill (slightly above page surface)
            HunkyTheme.surfaceRow

            // Hover layer
            if isHovering && !isItemRunning {
                HunkyTheme.surfaceRowHover.opacity(0.6)
            }

            // Running tint
            if isItemRunning {
                HunkyTheme.surfaceRowSelected.opacity(0.5)
            }

            // Failed wash
            if isItemFailed {
                HunkyTheme.severityCriticalSoft
            }

            // Bottom hairline
            VStack { Spacer(); Rectangle().fill(HunkyTheme.hairline).frame(height: 1) }
        }
    }

    private var isItemRunning: Bool {
        if case .running = item.status { return true }
        return false
    }

    private var isItemFailed: Bool {
        if case .failed = item.status { return true }
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

// MARK: - Disc icon

private struct DiscIcon: View {
    let item: FileItem

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 22, weight: .light))
            .frame(width: 28, height: 28)
            .foregroundStyle(iconColor)
            .accessibilityHidden(true)
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
        case .running: return HunkyTheme.accent
        default:       return HunkyTheme.inkTertiary
        }
    }
}

// MARK: - Format / platform chips

private struct FormatChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(HunkyType.formatChip)
            .tracking(0.4)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(HunkyTheme.inkSecondary)
            .background(HunkyTheme.surfaceControl, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel(text)
    }
}

private struct PlatformChip: View {
    let platform: DiscInspector.Platform

    var body: some View {
        Text(label)
            .font(HunkyType.formatChip)
            .tracking(0.4)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(textColor)
            .background(bgColor, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel(label)
    }

    private var label: String {
        switch platform {
        case .ps1:       return "PS1"
        case .saturn:    return "Saturn"
        case .dreamcast: return "Dreamcast"
        case .cdrom:     return "CD-ROM"
        }
    }

    private var bgColor: Color {
        switch platform {
        case .ps1:       return HunkyTheme.platformPSX
        case .saturn:    return HunkyTheme.platformSaturn
        case .dreamcast: return HunkyTheme.platformDreamcast
        case .cdrom:     return HunkyTheme.platformCDROM
        }
    }

    private var textColor: Color {
        // Platform colors are saturated; sit dark text on top so the chip reads.
        switch platform {
        case .ps1:       return Color(red: 0.10, green: 0.08, blue: 0.03)
        case .saturn:    return Color(red: 0.10, green: 0.03, blue: 0.03)
        case .dreamcast: return Color(red: 0.02, green: 0.06, blue: 0.10)
        case .cdrom:     return HunkyTheme.inkPrimary
        }
    }
}

// MARK: - Action pill

private struct ActionPill: View {
    let action: Action
    let armed: Bool
    let dimmed: Bool
    var hasChevron: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: action.systemImage)
                .font(.system(size: 11))
                .foregroundStyle(armed ? HunkyTheme.accent : HunkyTheme.inkTertiary)
            Text(action.label)
                .font(.system(size: 11.5))
                .foregroundStyle(armed ? HunkyTheme.accent : HunkyTheme.inkSecondary)
            if hasChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(armed ? HunkyTheme.accent.opacity(0.6) : HunkyTheme.inkTertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(HunkyTheme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(armed ? HunkyTheme.accent.opacity(0.4) : HunkyTheme.hairline, lineWidth: 1)
        )
        .opacity(dimmed ? 0.6 : 1.0)
    }
}
