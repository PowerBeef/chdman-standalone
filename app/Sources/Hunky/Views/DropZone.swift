import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Sidebar intake control. Drop targeting remains window-wide so the surface
/// stays native and calm instead of becoming a large custom drop zone.
struct DropZone: View {
    let onDrop: ([URL]) -> Void

    var body: some View {
        Button(action: pickFiles) {
            Label("Add Files", systemImage: "plus")
                .font(HunkyType.callout)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .liquidGlassPanel(tint: HunkyTheme.Glass.controlTint.opacity(0.68), cornerRadius: 10, textureOpacity: 0, interactive: true)
        .help("Add files or folders (Command-O)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Add disc files or folders")
        .accessibilityHint("Click Add Files, or drop CUE, GDI, TOC, ISO, CHD files or folders anywhere on this window.")
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
            HunkyTheme.Accent.base.opacity(0.08)

            Label("Release to add disc images", systemImage: "arrow.down.to.line")
                .font(HunkyType.callout)
                .fontWeight(.semibold)
                .foregroundStyle(HunkyTheme.Accent.base)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .liquidGlassPanel(tint: HunkyTheme.Glass.panelTint, cornerRadius: 10, textureOpacity: 0)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
