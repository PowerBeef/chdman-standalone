import SwiftUI

// MARK: - Footer

struct HunkyFooter<Left: View, Right: View>: View {
    let left: Left
    let right: Right

    init(@ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.left = left()
        self.right = right()
    }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 12) { left }
                Spacer(minLength: 12)
                HStack(spacing: 12) { right }
            }
            .font(HunkyType.label)
            .foregroundStyle(HunkyTheme.Ink.tertiary)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .liquidGlassPanel(tint: HunkyTheme.Surface.footer, cornerRadius: 0, textureOpacity: 0.04)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(HunkyTheme.Hairline.base)
                    .frame(height: 1)
            }
        }
    }
}

/// A right-aligned mono path label for the footer.
struct HunkyFooterPath: View {
    let text: String

    var body: some View {
        Text(text)
            .font(HunkyType.mono)
            .foregroundStyle(HunkyTheme.Ink.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
