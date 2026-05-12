import SwiftUI

struct TextOutputSheet: View {
    let title: String
    let subtitle: String
    let text: String
    let done: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(HunkyTheme.Accent.base)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(subtitle)
                            .font(HunkyType.label).fontWeight(.semibold)
                            .foregroundStyle(HunkyTheme.Accent.base)
                        Text(title).font(HunkyType.title)
                    }
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button("Done", action: done)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .padding([.horizontal, .top], 12)
            Rectangle()
                .fill(HunkyTheme.Hairline.base)
                .frame(height: 1)
            ScrollView {
                Text(text)
                    .font(HunkyType.mono)
                    .foregroundStyle(HunkyTheme.Ink.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .liquidGlassPanel(tint: HunkyTheme.Glass.panelDeepTint, cornerRadius: 12, textureOpacity: 0)
            .padding([.horizontal, .bottom], 12)
        }
        .frame(minWidth: 560, minHeight: 380)
    }
}
