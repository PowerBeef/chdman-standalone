import SwiftUI

struct CompletedRunChip: View {
    let summary: RunSummary
    let canRevealInFinder: Bool
    let onRevealInFinder: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(tintSoft)
                Image(systemName: summary.isClean ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(HunkyType.body).fontWeight(.semibold)
                    .foregroundStyle(tint)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(headlineText)
                    .font(HunkyType.callout).fontWeight(.semibold)
                    .foregroundStyle(tint)
                Text(metaText)
                    .font(HunkyType.mono)
                    .foregroundStyle(HunkyTheme.Ink.tertiary)
            }

            Spacer()

            if canRevealInFinder {
                Button("Reveal in Finder", action: onRevealInFinder)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlassPanel(tint: tintSoft, cornerRadius: 10, textureOpacity: 0)
    }

    private var tint: Color {
        summary.isClean ? HunkyTheme.Severity.verified : HunkyTheme.Severity.caution
    }

    private var tintSoft: Color {
        summary.isClean ? HunkyTheme.Severity.verifiedSoft : HunkyTheme.Severity.cautionSoft
    }

    private var headlineText: String {
        var parts: [String] = ["Queue run complete"]
        if summary.succeeded > 0 {
            parts.append(summary.successBreakdown)
        }
        if summary.failed > 0 {
            parts.append("\(summary.failed) failed")
        }
        if summary.cancelled > 0 {
            parts.append("\(summary.cancelled) cancelled")
        }
        return parts.joined(separator: ", ")
    }

    private var metaText: String {
        let elapsed = summary.endedAt.timeIntervalSince(summary.startedAt)
        return "elapsed \(formatElapsed(elapsed))"
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 {
            return "\(total)s"
        }
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
