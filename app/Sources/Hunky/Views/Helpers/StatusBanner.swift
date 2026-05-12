import SwiftUI

struct StatusBanner: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .lineLimit(2)
                .foregroundStyle(HunkyTheme.Ink.secondary)
            Spacer(minLength: 0)
        }
        .font(HunkyType.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .liquidGlassPanel(tint: tint.opacity(0.18), cornerRadius: 8, textureOpacity: 0)
    }
}
