import SwiftUI
import UniformTypeIdentifiers

/// Empty-state cluster: animated rainbow disc + headline + format chips +
/// Browse button. Drop targeting is window-wide; the drag overlay lives at
/// `ContentView`'s ZStack root, not on this view.
struct DropZone: View {
    let onDrop: ([URL]) -> Void

    var body: some View {
        ZStack {
            DropZoneGrid()
                .opacity(0.5)

            VStack(spacing: 22) {
                HeroDisc()
                    .frame(width: 168, height: 168)

                VStack(spacing: 6) {
                    Text("Drop discs to archive")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(HunkyTheme.inkPrimary)
                    Text("Hunky verifies, converts, and catalogs.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(HunkyTheme.inkTertiary)
                }

                FormatChipsRow()

                Button(action: pickFiles) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12, weight: .medium))
                        Text("Browse files…")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .foregroundStyle(Color(red: 0.02, green: 0.08, blue: 0.10))
                    .background(HunkyTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: HunkyTheme.accent.opacity(0.4), radius: 14, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Text("Tip — drop a folder of dumps and Hunky picks the right action per file.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(HunkyTheme.inkQuaternary)
                    Kbd(text: "⌘O")
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Add disc files or folders")
        .accessibilityHint("Click Browse, or drop CUE, GDI, TOC, ISO, CHD files or folders anywhere on this window.")
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "chd") ?? .data,
            UTType(filenameExtension: "cue") ?? .data,
            UTType(filenameExtension: "gdi") ?? .data,
            UTType(filenameExtension: "iso") ?? .data,
            UTType(filenameExtension: "toc") ?? .data,
        ]
        panel.prompt = "Add"
        if panel.runModal() == .OK {
            onDrop(panel.urls)
        }
    }
}

// MARK: - Hero disc art
//
// Concentric rings + 36 tick marks + central hub. Spins continuously over
// 22 seconds via TimelineView; honors accessibilityReduceMotion.

private struct HeroDisc: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let angle = reduceMotion ? 0 : (elapsed / HunkyMotion.heroSpinPeriod) * 360
            Canvas { ctx, size in
                drawDisc(ctx: ctx, size: size, rotation: angle)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawDisc(ctx: GraphicsContext, size: CGSize, rotation: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outerR = min(size.width, size.height) / 2 - 6

        // Disc body — radial gradient
        let bodyRect = CGRect(
            x: center.x - outerR, y: center.y - outerR,
            width: outerR * 2, height: outerR * 2
        )
        let bodyGradient = Gradient(colors: [
            oklchColor(0.30, 0.020, 240),
            oklchColor(0.24, 0.015, 240),
            oklchColor(0.18, 0.012, 240),
        ])
        ctx.fill(
            Path(ellipseIn: bodyRect),
            with: .radialGradient(bodyGradient, center: center, startRadius: 0, endRadius: outerR)
        )
        ctx.stroke(Path(ellipseIn: bodyRect), with: .color(oklchColor(0.35, 0.012, 240)), lineWidth: 0.8)

        // Rotate context for the spinning elements
        var spinCtx = ctx
        spinCtx.translateBy(x: center.x, y: center.y)
        spinCtx.rotate(by: .degrees(rotation))
        spinCtx.translateBy(x: -center.x, y: -center.y)

        // Rainbow band — dashed
        let rainbowR: CGFloat = outerR * 0.90
        let rainbowGradient = Gradient(stops: [
            .init(color: oklchColor(0.74, 0.15, 220, alpha: 0.4), location: 0.0),
            .init(color: oklchColor(0.78, 0.18, 145, alpha: 0.3), location: 0.35),
            .init(color: oklchColor(0.72, 0.18, 295, alpha: 0.3), location: 0.7),
            .init(color: oklchColor(0.82, 0.15, 80, alpha: 0.3), location: 1.0),
        ])
        let rainbowRect = CGRect(
            x: center.x - rainbowR, y: center.y - rainbowR,
            width: rainbowR * 2, height: rainbowR * 2
        )
        var rainbowStroke = StrokeStyle(lineWidth: 14, lineCap: .butt, dash: [2, 4])
        rainbowStroke.dash = [2, 4]
        spinCtx.stroke(
            Path(ellipseIn: rainbowRect),
            with: .linearGradient(rainbowGradient,
                                  startPoint: .init(x: 0, y: 0),
                                  endPoint: .init(x: size.width, y: size.height)),
            style: rainbowStroke
        )
        spinCtx.opacity = 1.0

        // Concentric guide rings
        for r in [outerR * 0.67, outerR * 0.56, outerR * 0.46] {
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            spinCtx.stroke(Path(ellipseIn: rect), with: .color(oklchColor(0.30, 0.012, 240)), lineWidth: 0.6)
        }

        // 36 tick marks
        let tickInner = outerR * 0.78
        let tickOuter = outerR * 0.74
        for i in 0..<36 {
            let theta = Double(i) * 10.0 * .pi / 180.0
            let cosT = cos(theta - .pi / 2)
            let sinT = sin(theta - .pi / 2)
            var p = Path()
            p.move(to: CGPoint(x: center.x + cosT * tickOuter, y: center.y + sinT * tickOuter))
            p.addLine(to: CGPoint(x: center.x + cosT * tickInner, y: center.y + sinT * tickInner))
            spinCtx.stroke(p, with: .color(oklchColor(0.40, 0.012, 240)), lineWidth: 0.8)
        }

        // Inner hub
        let hubR: CGFloat = outerR * 0.28
        let hubRect = CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)
        spinCtx.fill(Path(ellipseIn: hubRect), with: .color(oklchColor(0.16, 0.012, 240)))
        spinCtx.stroke(Path(ellipseIn: hubRect), with: .color(oklchColor(0.35, 0.012, 240)), lineWidth: 0.8)

        // Inner ring
        let innerRingR: CGFloat = outerR * 0.18
        let innerRingRect = CGRect(x: center.x - innerRingR, y: center.y - innerRingR, width: innerRingR * 2, height: innerRingR * 2)
        spinCtx.stroke(Path(ellipseIn: innerRingRect), with: .color(oklchColor(0.30, 0.012, 240)), lineWidth: 0.6)

        // Spindle hole
        let holeR: CGFloat = outerR * 0.10
        let holeRect = CGRect(x: center.x - holeR, y: center.y - holeR, width: holeR * 2, height: holeR * 2)
        spinCtx.fill(Path(ellipseIn: holeRect), with: .color(oklchColor(0.18, 0.012, 240)))
        spinCtx.stroke(Path(ellipseIn: holeRect), with: .color(oklchColor(0.40, 0.012, 240)), lineWidth: 0.6)

        // Static specular highlight (not rotated)
        let highlightCenter = CGPoint(x: size.width * 0.36, y: size.height * 0.33)
        var hctx = ctx
        hctx.translateBy(x: highlightCenter.x, y: highlightCenter.y)
        hctx.rotate(by: .degrees(-30))
        hctx.translateBy(x: -highlightCenter.x, y: -highlightCenter.y)
        let highlightRect = CGRect(x: highlightCenter.x - 22, y: highlightCenter.y - 10, width: 44, height: 20)
        hctx.fill(
            Path(ellipseIn: highlightRect),
            with: .color(oklchColor(0.85, 0.05, 220, alpha: 0.06))
        )
    }
}

// MARK: - Format chips row

private struct FormatChipsRow: View {
    private let formats = ["CUE", "GDI", "TOC", "ISO", "CHD"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(formats, id: \.self) { fmt in
                Text(fmt)
                    .font(HunkyType.formatChip)
                    .tracking(0.4)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(HunkyTheme.inkSecondary)
                    .background(HunkyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(HunkyTheme.hairline, lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Kbd badge

struct Kbd: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(HunkyTheme.inkSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(HunkyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(HunkyTheme.hairline, lineWidth: 1)
            )
    }
}

// MARK: - Subtle dot grid background

private struct DropZoneGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 22
            let dot: CGFloat = 1
            let cols = Int(size.width / spacing) + 2
            let rows = Int(size.height / spacing) + 2
            for r in 0..<rows {
                for c in 0..<cols {
                    let x = CGFloat(c) * spacing
                    let y = CGFloat(r) * spacing
                    let rect = CGRect(x: x - dot/2, y: y - dot/2, width: dot, height: dot)
                    ctx.fill(Path(ellipseIn: rect), with: .color(oklchColor(0.30, 0.012, 240, alpha: 0.5)))
                }
            }
        }
        .mask(
            // Fade the grid out toward the edges
            RadialGradient(
                colors: [.black, .black.opacity(0.0)],
                center: .center,
                startRadius: 60,
                endRadius: 380
            )
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Drop overlay (window-wide)

struct WindowDropOverlay: View {
    var body: some View {
        ZStack {
            HunkyTheme.accent.opacity(0.06)
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    HunkyTheme.accent,
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .padding(12)

            HStack(spacing: 8) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 14, weight: .semibold))
                Text("Release to add")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(HunkyTheme.accent)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}

// MARK: - OKLCH helper (shared with HunkyTheme; kept private here for the canvas drawings)

private func oklchColor(_ L: Double, _ C: Double, _ h: Double, alpha: Double = 1.0) -> Color {
    let hRad = h * .pi / 180
    let a = C * cos(hRad)
    let b = C * sin(hRad)
    let lPrime = L + 0.3963377774 * a + 0.2158037573 * b
    let mPrime = L - 0.1055613458 * a - 0.0638541728 * b
    let sPrime = L - 0.0894841775 * a - 1.2914855480 * b
    let lLin = lPrime * lPrime * lPrime
    let mLin = mPrime * mPrime * mPrime
    let sLin = sPrime * sPrime * sPrime
    let lr = 4.0767416621 * lLin - 3.3077115913 * mLin + 0.2309699292 * sLin
    let lg = -1.2684380046 * lLin + 2.6097574011 * mLin - 0.3413193965 * sLin
    let lb = -0.0041960863 * lLin - 0.7034186147 * mLin + 1.7076147010 * sLin
    func enc(_ x: Double) -> Double {
        let c = max(0.0, min(1.0, x))
        return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1.0 / 2.4) - 0.055
    }
    return Color(.sRGB, red: max(0, min(1, enc(lr))), green: max(0, min(1, enc(lg))), blue: max(0, min(1, enc(lb))), opacity: alpha)
}
