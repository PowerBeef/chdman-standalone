import AppKit
import SwiftUI

// MARK: - Column geometry shared between header and row
//
// Four columns total: disc / audit / action / status. Rows stay flat and are
// separated by a 1 pt hairline; platform identity lives in a compact metadata
// badge instead of a colored row edge.

enum QueueColumns {
    static let auditWidth: CGFloat = 206
    static let actionWidth: CGFloat = 124
    static let statusWidth: CGFloat = 132
    static let columnSpacing: CGFloat = 14
    static let rowLeadingPadding: CGFloat = 14
    static let rowVerticalPadding: CGFloat = 12
    static let rowTrailingPadding: CGFloat = 14
}

// MARK: - Column header

struct QueueColumnHeader: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: QueueColumns.columnSpacing) {
            label("Slot")
                .frame(maxWidth: .infinity, alignment: .leading)
            label("Ready Check")
                .frame(width: QueueColumns.auditWidth, alignment: .leading)
            label("Action")
                .frame(width: QueueColumns.actionWidth, alignment: .leading)
            label("Status")
                .frame(width: QueueColumns.statusWidth, alignment: .leading)
        }
        .padding(.leading, QueueColumns.rowLeadingPadding)
        .padding(.trailing, QueueColumns.rowTrailingPadding)
        .padding(.vertical, 7)
        .liquidGlassPanel(tint: HunkyTheme.Glass.panelDeepTint, cornerRadius: 0, textureOpacity: 0.02)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HunkyTheme.Hairline.base)
                .frame(height: 1)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(HunkyType.label)
            .fontWeight(.semibold)
            .foregroundStyle(HunkyTheme.Ink.tertiary)
    }
}

// MARK: - Row

struct QueueRow: View {
    @Bindable var item: FileItem
    let isQueueRunning: Bool
    let showPlatformBadge: Bool
    let onRemove: () -> Void
    let onRetry: () -> Void
    let onShowInfo: () -> Void
    let onShowLog: () -> Void

    @State private var isWarningsExpanded = false
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
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
        .padding(.leading, QueueColumns.rowLeadingPadding)
        .padding(.vertical, QueueColumns.rowVerticalPadding)
        .padding(.trailing, QueueColumns.rowTrailingPadding)
        .background(rowBackground)
        .glassEffect(.regular.tint(rowGlassTint), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HunkyTheme.Glass.stroke, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HunkyTheme.Surface.bevel, lineWidth: 1)
                .padding(1)
        )
        .animation(reduceMotion ? nil : HunkyMotion.snap, value: statusKey)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(accessibilityValueText)
        .accessibilityHint("Swipe up or down for actions, double-tap to activate.")
        .accessibilityAction(named: "Change Action") {
            guard !isQueueRunning else { return }
            // Cycle to next action
            let available = Action.defaultActions(for: item.kind)
            if let currentIndex = available.firstIndex(of: item.action),
               available.count > 1 {
                let nextIndex = (currentIndex + 1) % available.count
                item.action = available[nextIndex]
            }
        }
        .accessibilityAction(named: "Remove") {
            if !isQueueRunning && !isItemRunning { onRemove() }
        }
        .contextMenu {
            contextMenuContent
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if let outputURL = item.outputURL, item.action != .info {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([outputURL])
            }
        }
        if item.logOutput != nil {
            Button("View Log") { onShowLog() }
        }
        if isItemFailed {
            Button("Copy Error") { copyLog() }
        }
        if case .failed = item.status, !isQueueRunning {
            Button("Retry") { onRetry() }
        } else if case .cancelled = item.status, !isQueueRunning {
            Button("Retry") { onRetry() }
        }
        Menu("Change Action") {
            ForEach(Action.defaultActions(for: item.kind)) { action in
                Button {
                    item.action = action
                } label: {
                    Label(action.label, systemImage: action.systemImage)
                }
            }
        }
        .disabled(!isItemIdle || isQueueRunning)
        Divider()
        if !isItemRunning {
            Button("Remove") { onRemove() }
                .disabled(isQueueRunning)
        }
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
                    .font(HunkyType.title)
                    .foregroundStyle(HunkyTheme.Ink.primary)

                discChipsLine

                if let meta = telemetryMetaLine() {
                    Text(meta)
                        .font(HunkyType.mono)
                        .foregroundStyle(HunkyTheme.Ink.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }

    private var discChipsLine: some View {
        HStack(spacing: 5) {
            FormatChip(text: item.typeChip)
            if showPlatformBadge, let platform = item.identity?.platform, platform != .cdrom {
                PlatformBadge(platform: platform)
            }
            if let identity = item.identity?.bestTitle {
                Text(identity)
                    .font(HunkyType.label)
                    .foregroundStyle(HunkyTheme.Ink.secondary)
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

    private func telemetryMetaLine() -> String? {
        telemetryMeta()?
            .map { "\($0.key) \($0.value)" }
            .joined(separator: ", ")
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
        let style = item.redumpAggregate.auditStyle(corruptedMeta: corruptedMetaLine())
        HStack(alignment: .top, spacing: 6) {
            if let icon = style.icon {
                Image(systemName: icon)
                    .font(HunkyType.callout)
                    .foregroundStyle(style.iconColor)
                    .frame(width: 13)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(style.title)
                    .font(HunkyType.status)
                    .foregroundStyle(style.titleColor)
                    .fixedSize(horizontal: false, vertical: true)
                if let meta = style.meta {
                    Text(meta)
                        .font(HunkyType.mono)
                        .foregroundStyle(HunkyTheme.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func corruptedMetaLine() -> String {
        // We don't carry the *expected* CRC in the enum, so surface what we know:
        // the bin's filename and a 4-char prefix of its actual CRC.
        for ref in item.references {
            if case .sizeMatchedButCRCMismatch = item.redumpStatuses[ref.url],
               let fp = item.referenceFingerprints[ref.url] {
                let got = String(format: "%08x", fp.crc32)
                return "size match, got \(got.prefix(4))"
            }
        }
        return "size matched, wrong CRC"
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
                    .font(HunkyType.label)
                Text(refsSummaryText(total: total, missing: missing))
                Image(systemName: "chevron.right")
                    .font(HunkyType.micro)
                    .opacity(0.5)
                    .rotationEffect(.degrees(isWarningsExpanded ? 90 : 0))
            }
            .font(HunkyType.label2)
            .foregroundStyle(isOK ? HunkyTheme.Ink.tertiary : HunkyTheme.Severity.caution)
        }
        .buttonStyle(.plain)
        .help(isOK ? "All referenced files are present." : "Some referenced files are missing or wrong size.")

        if isWarningsExpanded {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(item.references.enumerated()), id: \.offset) { _, ref in
                    HStack(spacing: 5) {
                        Image(systemName: ref.exists ? "circle.fill" : "exclamationmark.triangle.fill")
                            .imageScale(.small)
                            .foregroundStyle(ref.exists ? HunkyTheme.Ink.tertiary : HunkyTheme.Severity.caution)
                            .accessibilityHidden(true)
                        Text(ref.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(ref.exists ? HunkyTheme.Ink.tertiary : HunkyTheme.Ink.primary)
                    }
                    .font(HunkyType.label2)
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
        return "\(base), \(missing) missing"
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
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch item.status {
        case .idle:
            HStack(spacing: 6) {
                Image(systemName: "circle")
                    .font(HunkyType.label)
                Text("Ready")
            }
            .font(HunkyType.status)
            .foregroundStyle(HunkyTheme.Ink.secondary)
        case .running(let progress):
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(HunkyType.status)
                        .monospacedDigit()
                        .foregroundStyle(HunkyTheme.Accent.base)
                }
                progressBar(value: progress)
                    .frame(height: 5)
            }
            .accessibilityLabel("Progress for \(item.displayName)")
            .accessibilityValue("\(Int((progress * 100).rounded())) percent")
        case .done:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(HunkyType.label)
                Text(doneText)
            }
            .font(HunkyType.status)
            .fontWeight(.medium)
            .foregroundStyle(HunkyTheme.Severity.verified)
            .lineLimit(1)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                Image(systemName: "xmark.octagon.fill")
                    .font(HunkyType.label)
                Text("Failed")
                        .lineLimit(1)
                }
                .font(HunkyType.status)
                .fontWeight(.medium)
                .foregroundStyle(HunkyTheme.Severity.critical)
                Text(message)
                    .font(HunkyType.mono)
                    .foregroundStyle(HunkyTheme.Severity.critical.opacity(0.85))
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        case .cancelled:
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle")
                    .font(HunkyType.label)
                Text("Cancelled")
            }
            .font(HunkyType.status)
            .foregroundStyle(HunkyTheme.Ink.tertiary)
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
        HoverIconButton(label: label, systemImage: systemImage, action: action)
    }

    private var removeButton: some View {
        iconButton("Remove from queue", systemImage: "xmark", action: onRemove)
            .disabled(isItemRunning || isQueueRunning)
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
                    .fill(HunkyTheme.Surface.sunken)
                Capsule()
                    .fill(HunkyTheme.Accent.base)
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
        TimelineView(.periodic(from: Date(), by: 0.066)) { context in
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

    // MARK: - Background

    @ViewBuilder
    private var rowBackground: some View {
        ZStack {
            rowGlassTint.opacity(0.16)

            // Hover layer
            if isHovering && !isItemRunning {
                HunkyTheme.Surface.rowHover.opacity(0.46)
            }

            // Running tint
            if isItemRunning {
                HunkyTheme.Surface.rowSelected.opacity(0.50)
            }

            // Failed wash
            if isItemFailed {
                HunkyTheme.Severity.criticalSoft.opacity(0.85)
            }

            ConsoleTextureBackground(opacity: 0.045)
        }
    }

    private var rowGlassTint: Color {
        if isItemFailed { return HunkyTheme.Severity.criticalSoft }
        if isItemRunning { return HunkyTheme.Surface.rowSelected }
        if isHovering { return HunkyTheme.Surface.rowHover }
        return HunkyTheme.Surface.row
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

    /// Status discriminant used for animation diffing. `FileItem.Status` is
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

    // MARK: - Accessibility

    private var accessibilityLabelText: String {
        var parts: [String] = [item.displayName]
        if let platform = item.identity?.platform {
            parts.append(platform.rawValue)
        }
        parts.append(item.action.label)
        parts.append(statusDescription)
        return parts.joined(separator: ", ")
    }

    private var accessibilityValueText: String {
        switch item.status {
        case .running(let progress):
            return "\(Int((progress * 100).rounded())) percent complete"
        case .done(let message):
            return message ?? "Completed"
        case .failed(let message):
            return "Failed: \(message)"
        case .cancelled:
            return "Cancelled"
        case .idle:
            return "Ready"
        }
    }

    private var statusDescription: String {
        switch item.status {
        case .idle:       return "Ready"
        case .running:    return "Running"
        case .done:       return "Completed"
        case .failed:     return "Failed"
        case .cancelled:  return "Cancelled"
        }
    }
}

// MARK: - Disc icon
//
// Renders the disc / archive symbol at rest. While the row is running the
// icon morphs into a spinning-disc progress ring with a percent readout.

private struct DiscIcon: View {
    let item: FileItem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if case .running(let progress) = item.status {
            DiscProgressRing(progress: progress)
        } else {
            Image(systemName: iconName)
                .font(.system(size: 25, weight: .light))
                .frame(width: 34, height: 34)
                .foregroundStyle(iconColor)
                .scaleEffect(statusScale)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: statusKey)
                .accessibilityHidden(true)
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
        case .done:      return HunkyTheme.Severity.verified
        case .failed:    return HunkyTheme.Severity.critical
        case .cancelled: return HunkyTheme.Ink.tertiary
        default:         return HunkyTheme.Ink.tertiary
        }
    }

    private var statusScale: CGFloat {
        switch item.status {
        case .done, .failed: return 1.1
        default:              return 1.0
        }
    }

    private var statusKey: String {
        switch item.status {
        case .done:      return "done"
        case .failed:    return "failed"
        case .cancelled: return "cancelled"
        default:         return "idle"
        }
    }
}

// MARK: - Spinning-disc progress ring
//
// 28pt ring with a filled arc representing progress, a tiny percent label
// at the center, and a subtle continuously rotating angular gradient
// behind the arc to convey "actively running." Reduce-motion disables
// the rotation but preserves the static arc.

private struct DiscProgressRing: View {
    let progress: Double  // 0...1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(HunkyTheme.Surface.sunken, lineWidth: 2.2)

            // Continuously rotating sweep behind the arc, only when the
            // user hasn't asked us to stop moving.
            if !reduceMotion {
                ConicSweep()
                    .opacity(0.55)
            }

            // Filled progress arc runs from top, clockwise.
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    HunkyTheme.Accent.base,
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percent label
            Text("\(Int((progress * 100).rounded()))")
                .font(HunkyType.micro)
                .foregroundStyle(HunkyTheme.Accent.base)
                .monospacedDigit()
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }
}

private struct ConicSweep: View {
    var body: some View {
        TimelineView(.periodic(from: Date(), by: 0.066)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = (t / HunkyMotion.progressSpinPeriod * 360)
                .truncatingRemainder(dividingBy: 360)
            Circle()
                .inset(by: 3)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: HunkyTheme.Accent.soft, location: 0.25),
                            .init(color: .clear, location: 0.75),
                        ]),
                        center: .center
                    ),
                    lineWidth: 3
                )
                .rotationEffect(.degrees(angle))
        }
    }
}

// MARK: - Hover icon button

private struct HoverIconButton: View {
    let label: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(HunkyType.label)
                .frame(width: 22, height: 22)
                .foregroundStyle(isHovering ? HunkyTheme.Ink.primary : HunkyTheme.Ink.tertiary)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(HunkyTheme.Ink.tertiary.opacity(isHovering ? 0.12 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Format / platform chips

private struct FormatChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(HunkyType.formatChip)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(HunkyTheme.Accent.base)
            .liquidGlassChip(tint: HunkyTheme.Accent.soft, cornerRadius: 5)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel(text)
    }
}

private struct PlatformBadge: View {
    let platform: DiscInspector.Platform

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(markerColor)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(label)
                .font(HunkyType.formatChip)
                .foregroundStyle(HunkyTheme.Ink.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .liquidGlassChip(tint: markerColor.opacity(0.22), cornerRadius: 5)
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

    private var markerColor: Color {
        switch platform {
        case .ps1:       return HunkyTheme.Platform.psx
        case .saturn:    return HunkyTheme.Platform.saturn
        case .dreamcast: return HunkyTheme.Platform.dreamcast
        case .cdrom:     return HunkyTheme.Platform.cdrom
        }
    }
}

// MARK: - Action pill

private struct ActionPill: View {
    let action: Action
    let armed: Bool
    let dimmed: Bool
    var hasChevron: Bool = false

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: action.systemImage)
                .font(HunkyType.label)
                .foregroundStyle(armed ? HunkyTheme.Accent.base : HunkyTheme.Ink.tertiary)
            Text(action.label)
                .font(HunkyType.label)
                .foregroundStyle(armed ? HunkyTheme.Accent.base : HunkyTheme.Ink.secondary)
            if hasChevron {
                Image(systemName: "chevron.down")
                    .font(HunkyType.micro)
                    .foregroundStyle(armed ? HunkyTheme.Accent.base.opacity(0.6) : HunkyTheme.Ink.tertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .liquidGlassChip(
            tint: pillTint,
            cornerRadius: 6,
            interactive: armed
        )
        .opacity(dimmed ? 0.6 : 1.0)
        .onHover { isHovering = $0 }
    }

    private var pillTint: Color {
        if isHovering && armed {
            return HunkyTheme.Accent.soft.opacity(0.6)
        }
        return armed ? HunkyTheme.Accent.soft : HunkyTheme.Glass.controlTint
    }
}
