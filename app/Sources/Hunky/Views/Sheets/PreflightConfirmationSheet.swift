import SwiftUI

struct PreflightSheetPayload: Identifiable {
    let id = UUID()
    let issues: [PreflightIssue]
}

struct PreflightConfirmationSheet: View {
    let issues: [PreflightIssue]
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var copy: ReadyCheckCopy {
        ReadyCheckCopy(issues: issues)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(copy.hasCritical ? HunkyTheme.Severity.criticalSoft : HunkyTheme.Severity.cautionSoft)
                    Image(systemName: copy.hasCritical ? "exclamationmark.triangle.fill" : "checklist")
                        .font(HunkyType.title)
                        .foregroundStyle(copy.hasCritical ? HunkyTheme.Severity.critical : HunkyTheme.Severity.caution)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready Check")
                        .font(HunkyType.label).fontWeight(.semibold)
                        .foregroundStyle(HunkyTheme.Accent.base)
                    Text(copy.headlineText)
                        .font(HunkyType.title)
                        .foregroundStyle(HunkyTheme.Ink.primary)
                    Text(copy.paragraphText)
                        .font(HunkyType.callout)
                        .foregroundStyle(HunkyTheme.Ink.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 7) {
                if issues.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(HunkyTheme.Severity.verified)
                        Text("No current Ready Check issues.")
                            .foregroundStyle(HunkyTheme.Ink.secondary)
                    }
                    .font(HunkyType.label)
                } else {
                    ForEach(issues) { issue in
                        issueLine(issue)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassPanel(tint: copy.hasCritical ? HunkyTheme.Severity.criticalSoft : HunkyTheme.Glass.panelDeepTint, cornerRadius: 8, textureOpacity: 0.04)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Rectangle()
                .fill(HunkyTheme.Hairline.base)
                .frame(height: 1)

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(copy.confirmButtonTitle, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
                    .tint(confirmTint)
            }
            .padding(16)
        }
        .frame(minWidth: 480, idealWidth: 500)
    }

    private var confirmTint: Color {
        if copy.hasCritical { return HunkyTheme.Severity.critical }
        if issues.isEmpty { return HunkyTheme.Accent.base }
        return HunkyTheme.Severity.caution
    }

    private func issueLine(_ issue: PreflightIssue) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: issue.severity == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                .foregroundStyle(HunkyTheme.severityColor(issue.severity))
                .font(HunkyType.label)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.fileName)
                    .font(HunkyType.mono)
                    .foregroundStyle(HunkyTheme.Ink.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(issue.detail.isEmpty ? issue.title : issue.detail)
                    .font(HunkyType.label)
                    .foregroundStyle(HunkyTheme.Ink.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(issue.fileName), \(issue.severity.label): \(issue.title)")
    }
}
