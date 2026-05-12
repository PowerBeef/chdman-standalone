import SwiftUI

struct DiscBayPanel: View {
    @Bindable var queue: QueueController
    var intakeMessage: String?
    let onPickOutputDirectory: () -> Void
    let onAddFiles: ([URL]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            DropZone { urls in
                onAddFiles(urls)
            }

            if let intakeMessage {
                StatusBanner(text: intakeMessage, systemImage: "checkmark.circle", tint: HunkyTheme.Accent.base)
            }

            savePathModule

            Text("Supports CUE, GDI, TOC, ISO, CHD")
                .font(HunkyType.label)
                .foregroundStyle(HunkyTheme.Ink.tertiary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, HunkyLayout.sidebarHorizontalPadding)
        .padding(.top, 31)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HunkyTheme.Surface.sidebar.opacity(0.16))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(HunkyTheme.Hairline.base.opacity(0.58))
                .frame(width: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(HunkyTheme.Glass.controlTint)
                    .glassEffect(.regular.tint(HunkyTheme.Glass.controlTint), in: Circle())
                Image(systemName: "opticaldisc")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HunkyTheme.Ink.secondary)
            }
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Disc Bay")
                    .font(HunkyType.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(HunkyTheme.Ink.primary)
            }
        }
    }

    private var savePathModule: some View {
        Button {
            onPickOutputDirectory()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "externaldrive")
                    .font(.system(size: 19, weight: .regular))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(HunkyTheme.Ink.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Save Path")
                        .font(HunkyType.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(HunkyTheme.Ink.primary)
                    outputValue
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(HunkyType.label)
                    .foregroundStyle(HunkyTheme.Ink.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .liquidGlassPanel(tint: HunkyTheme.Glass.controlTint.opacity(0.82), cornerRadius: 10, textureOpacity: 0, interactive: true)
        .help("Choose output folder (Command-Shift-O)")
        .accessibilityLabel("Choose Save Path")
    }

    @ViewBuilder
    private var outputValue: some View {
        if let dir = queue.outputDirectory {
            HunkyFooterPath(text: dir.path(percentEncoded: false))
        } else {
            Text("~/Hunky Library")
                .font(HunkyType.callout)
                .foregroundStyle(HunkyTheme.Ink.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
