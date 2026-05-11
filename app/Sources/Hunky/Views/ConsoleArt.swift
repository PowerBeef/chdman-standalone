import AppKit
import SwiftUI

enum HunkyArt {
    static func image(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Art") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

struct HunkyResourceImage: View {
    let name: String
    var contentMode: ContentMode = .fit
    var opacity: Double = 1

    var body: some View {
        if let image = HunkyArt.image(named: name) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .opacity(opacity)
                .accessibilityHidden(true)
        } else {
            Color.clear.accessibilityHidden(true)
        }
    }
}

struct ConsoleTextureBackground: View {
    var opacity: Double = 0.20

    var body: some View {
        GeometryReader { proxy in
            HunkyResourceImage(name: "console-workbench-texture", contentMode: .fill, opacity: opacity)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay(HunkyTheme.Surface.base.opacity(0.22))
                .clipped()
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct ConsoleLED: View {
    let color: Color
    var size: CGFloat = 7
    var isLit: Bool = true

    var body: some View {
        Circle()
            .fill(isLit ? color : HunkyTheme.Ink.quaternary)
            .frame(width: size, height: size)
            .shadow(color: isLit ? color.opacity(0.55) : .clear, radius: isLit ? 4 : 0)
            .overlay(Circle().stroke(HunkyTheme.Ink.quaternary.opacity(0.35), lineWidth: 0.6))
            .accessibilityHidden(true)
    }
}

struct ConsoleTag: View {
    let text: String
    var tint: Color = HunkyTheme.Ink.tertiary
    var isMono: Bool = false

    var body: some View {
        Text(text)
            .font(isMono ? HunkyType.mono : HunkyType.label2)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .liquidGlassChip(tint: tint.opacity(0.7), cornerRadius: 5)
    }
}

private struct ConsolePanelModifier: ViewModifier {
    var fill: Color = HunkyTheme.Surface.consolePanel
    var cornerRadius: CGFloat = 14
    var textureOpacity: Double = 0.06

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                ZStack {
                    fill.opacity(0.18)
                    HunkyTheme.Accent.glow.opacity(0.10)
                    if textureOpacity > 0 {
                        ConsoleTextureBackground(opacity: textureOpacity)
                            .clipShape(shape)
                    }
                }
                .clipShape(shape)
            }
            .glassEffect(.regular.tint(fill), in: shape)
            .overlay(
                shape
                    .stroke(HunkyTheme.Glass.strokeStrong, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
                    .stroke(HunkyTheme.Surface.bevel, lineWidth: 1)
                    .padding(1)
            )
            .shadow(color: HunkyTheme.glassShadow, radius: 18, x: 0, y: 10)
    }
}

private struct LiquidGlassSurfaceModifier: ViewModifier {
    var tint: Color
    var cornerRadius: CGFloat
    var stroke: Color
    var textureOpacity: Double
    var interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let glass = interactive ? Glass.regular.tint(tint).interactive() : Glass.regular.tint(tint)

        content
            .background {
                ZStack {
                    tint.opacity(0.10)
                    if textureOpacity > 0 {
                        ConsoleTextureBackground(opacity: textureOpacity)
                            .clipShape(shape)
                    }
                }
                .clipShape(shape)
            }
            .glassEffect(glass, in: shape)
            .overlay(shape.stroke(stroke, lineWidth: 1))
    }
}

extension View {
    func consolePanel(
        fill: Color = HunkyTheme.Surface.consolePanel,
        cornerRadius: CGFloat = 14,
        textureOpacity: Double = 0.10
    ) -> some View {
        modifier(ConsolePanelModifier(fill: fill, cornerRadius: cornerRadius, textureOpacity: textureOpacity))
    }

    func liquidGlassPanel(
        tint: Color = HunkyTheme.Glass.panelTint,
        cornerRadius: CGFloat = 14,
        textureOpacity: Double = 0.08,
        interactive: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                tint: tint,
                cornerRadius: cornerRadius,
                stroke: HunkyTheme.Glass.stroke,
                textureOpacity: textureOpacity,
                interactive: interactive
            )
        )
    }

    func liquidGlassChip(
        tint: Color = HunkyTheme.Glass.controlTint,
        cornerRadius: CGFloat = 6,
        interactive: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                tint: tint,
                cornerRadius: cornerRadius,
                stroke: HunkyTheme.Hairline.base,
                textureOpacity: 0,
                interactive: interactive
            )
        )
    }
}
