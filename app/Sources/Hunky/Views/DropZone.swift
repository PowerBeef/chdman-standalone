import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Disc Bay intake controls. Drop targeting is window-wide; the drag overlay
/// lives at `ContentView`'s ZStack root, not on this view.
struct DropZone: View {
    let onDrop: ([URL]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                intakeIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text("Insert disc image")
                        .font(HunkyType.callout).fontWeight(.semibold)
                        .foregroundStyle(HunkyTheme.Ink.primary)
                    Text("Drop files anywhere in this window.")
                        .font(HunkyType.label2)
                        .foregroundStyle(HunkyTheme.Ink.tertiary)
                }
            }

            Button(action: pickFiles) {
                Label("Add Files or Folders...", systemImage: "plus")
                    .font(HunkyType.callout).fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.regular)
            .tint(HunkyTheme.Accent.base)
            .help("Add files or folders (Command-O)")

            HStack(spacing: 5) {
                ConsoleTag(text: "CUE")
                ConsoleTag(text: "GDI")
                ConsoleTag(text: "TOC")
                ConsoleTag(text: "ISO")
                ConsoleTag(text: "CHD")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .liquidGlassPanel(tint: HunkyTheme.Glass.panelDeepTint, cornerRadius: 12, textureOpacity: 0.08)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Add disc files or folders")
        .accessibilityHint("Click Add Files or Folders, or drop CUE, GDI, TOC, ISO, CHD files or folders anywhere on this window.")
    }

    private var intakeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(HunkyTheme.Accent.soft)
                .glassEffect(.regular.tint(HunkyTheme.Glass.controlTint), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Image(systemName: "tray.and.arrow.down")
                .font(HunkyType.title).fontWeight(.medium)
                .foregroundStyle(HunkyTheme.Accent.base)
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
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

// MARK: - Drop overlay

struct WindowDropOverlay: View {
    var body: some View {
        ZStack {
            HunkyTheme.Accent.base.opacity(0.10)

            HStack(spacing: 8) {
                Image(systemName: "arrow.down.to.line")
                    .font(HunkyType.callout).fontWeight(.semibold)
                Text("Release to load slots")
                    .font(HunkyType.callout).fontWeight(.semibold)
            }
            .foregroundStyle(HunkyTheme.Accent.base)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .liquidGlassPanel(tint: HunkyTheme.Glass.panelTint, cornerRadius: 9, textureOpacity: 0.03)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
