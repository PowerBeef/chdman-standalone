import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Empty-state cluster. Drop targeting is window-wide; the drag overlay lives
/// at `ContentView`'s ZStack root, not on this view.
struct DropZone: View {
    let onDrop: ([URL]) -> Void

    var body: some View {
        VStack(spacing: 20) {
            QuietDiscMark()
                .frame(width: 104, height: 104)

            VStack(spacing: 6) {
                Text("Drop files or folders")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(HunkyTheme.inkPrimary)
                Text("Add CUE, GDI, TOC, ISO, or CHD files. Hunky audits references and runs chdman locally.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(HunkyTheme.inkTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: 520)
            }

            FormatChipsRow()

            Button(action: pickFiles) {
                Label("Browse Files or Folders...", systemImage: "folder.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(HunkyTheme.accent)

            HStack(spacing: 6) {
                Text("Drop a folder and Hunky picks the right action per file.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(HunkyTheme.inkQuaternary)
                Kbd(text: "Cmd-O")
            }
        }
        .padding(28)
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

// MARK: - Static disc mark

private struct QuietDiscMark: View {
    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerR = min(size.width, size.height) / 2 - 5
            let bodyRect = CGRect(
                x: center.x - outerR,
                y: center.y - outerR,
                width: outerR * 2,
                height: outerR * 2
            )
            ctx.fill(
                Path(ellipseIn: bodyRect),
                with: .radialGradient(
                    Gradient(colors: [
                        HunkyTheme.surfaceRaised,
                        HunkyTheme.surfaceControl,
                        HunkyTheme.surfaceSunken
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: outerR
                )
            )
            ctx.stroke(Path(ellipseIn: bodyRect), with: .color(HunkyTheme.hairlineStrong), lineWidth: 1)

            let reflectionRect = CGRect(
                x: center.x - outerR * 0.72,
                y: center.y - outerR * 0.72,
                width: outerR * 1.44,
                height: outerR * 1.44
            )
            ctx.stroke(
                Path(ellipseIn: reflectionRect),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: HunkyTheme.accent.opacity(0.0), location: 0.0),
                        .init(color: HunkyTheme.accent.opacity(0.28), location: 0.44),
                        .init(color: HunkyTheme.accent.opacity(0.0), location: 1.0)
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: size.height)
                ),
                lineWidth: 5
            )

            let ringFactors: [CGFloat] = [0.66, 0.50]
            for factor in ringFactors {
                let r = outerR * factor
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                ctx.stroke(Path(ellipseIn: rect), with: .color(HunkyTheme.hairline), lineWidth: 0.8)
            }

            let hubR = outerR * 0.26
            let hubRect = CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)
            ctx.fill(Path(ellipseIn: hubRect), with: .color(HunkyTheme.surfaceSunken))
            ctx.stroke(Path(ellipseIn: hubRect), with: .color(HunkyTheme.hairlineStrong), lineWidth: 1)

            let holeR = outerR * 0.10
            let holeRect = CGRect(x: center.x - holeR, y: center.y - holeR, width: holeR * 2, height: holeR * 2)
            ctx.fill(Path(ellipseIn: holeRect), with: .color(HunkyTheme.surface))
            ctx.stroke(Path(ellipseIn: holeRect), with: .color(HunkyTheme.hairline), lineWidth: 1)
        }
        .accessibilityHidden(true)
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

// MARK: - Drop overlay

struct WindowDropOverlay: View {
    var body: some View {
        ZStack {
            HunkyTheme.accent.opacity(0.08)

            HStack(spacing: 8) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 14, weight: .semibold))
                Text("Release to add")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(HunkyTheme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(HunkyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HunkyTheme.hairlineStrong, lineWidth: 1)
            )
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
