import SwiftUI

struct DiscBayPanel: View {
    @Bindable var queue: QueueController
    var intakeMessage: String?
    let onPickOutputDirectory: () -> Void
    let onAddFiles: ([URL]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                HunkyResourceImage(name: "hunky-console-emblem")
                    .frame(width: 88, height: 88)
                    .clipped()

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                    ConsoleLED(color: HunkyTheme.Accent.base, size: 8)
                    Text("Disc Bay")
                        .font(HunkyType.title).fontWeight(.bold)
                        .foregroundStyle(HunkyTheme.Ink.primary)
                    }
                Text("Load sheets, images, or archives.")
                    .font(HunkyType.label)
                    .foregroundStyle(HunkyTheme.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            DropZone { urls in
                onAddFiles(urls)
            }

            if let intakeMessage {
                StatusBanner(text: intakeMessage, systemImage: "checkmark.circle", tint: HunkyTheme.Accent.base)
            }

            savePathModule
            bayReadinessModule

            Text("Hunky never overwrites existing output. Collisions get numbered filenames.")
                .font(HunkyType.label2)
                .foregroundStyle(HunkyTheme.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .consolePanel(fill: HunkyTheme.Surface.consolePanel, cornerRadius: 16, textureOpacity: 0.14)
    }

    private var savePathModule: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Save path", systemImage: "memorychip")
                    .font(HunkyType.sectionTitle)
                    .foregroundStyle(HunkyTheme.Ink.secondary)
                Spacer()
                Button("Choose") {
                    onPickOutputDirectory()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(HunkyTheme.Memory.base)
            }

            HStack(spacing: 7) {
                ConsoleLED(color: queue.outputDirectory == nil ? HunkyTheme.Ink.tertiary : HunkyTheme.Memory.base, size: 6, isLit: queue.outputDirectory != nil)
                outputFooterValue
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .liquidGlassChip(tint: HunkyTheme.Glass.controlTint, cornerRadius: 8)
        }
    }

    private var outputFooterValue: some View {
        Group {
            if let dir = queue.outputDirectory {
                HunkyFooterPath(text: dir.path(percentEncoded: false))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Same folder as source")
                    .font(HunkyType.formatChip)
                    .foregroundStyle(HunkyTheme.Ink.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var bayReadinessModule: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ready Check")
                .font(HunkyType.sectionTitle)
                .foregroundStyle(HunkyTheme.Ink.secondary)

            VStack(spacing: 7) {
                bayMetric(label: "Slots", value: "\(queue.items.count)", color: queue.items.isEmpty ? HunkyTheme.Ink.tertiary : HunkyTheme.Accent.base)
                bayMetric(label: "Waiting", value: "\(queue.pendingCount)", color: queue.pendingCount > 0 ? HunkyTheme.Memory.base : HunkyTheme.Ink.tertiary)
                bayMetric(label: "Warnings", value: "\(queue.riskCount)", color: queue.riskCount > 0 ? HunkyTheme.Severity.caution : HunkyTheme.Severity.verified)
            }
        }
    }

    private func bayMetric(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            ConsoleLED(color: color, size: 6, isLit: value != "0")
            Text(label)
                .font(HunkyType.label)
                .foregroundStyle(HunkyTheme.Ink.tertiary)
            Spacer()
            Text(value)
                .font(HunkyType.mono)
                .foregroundStyle(color)
        }
    }
}
