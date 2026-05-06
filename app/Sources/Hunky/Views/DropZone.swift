import SwiftUI
import UniformTypeIdentifiers

/// Empty-state cluster: icon + headline + format hint + Browse button.
///
/// There is intentionally no bordered drop-target rectangle. The whole window
/// is the drop target via `ContentView`'s `.onDrop` modifier; this view's job
/// is to communicate "drop discs here or click Browse" without competing with
/// the macOS toolbar above it. The `isDropping` flag dims and slightly scales
/// the cluster to confirm receipt during a drag.
struct DropZone: View {
    let onDrop: ([URL]) -> Void
    var isDropping: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "opticaldiscdrive")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Drop discs here")
                .font(.title3.weight(.semibold))

            Text("CUE, GDI, TOC, ISO, CHD, or a folder")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                pickFiles()
            } label: {
                Label("Browse…", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .scaleEffect(isDropping ? 1.02 : 1.0)
        .opacity(isDropping ? 0.85 : 1.0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isDropping)
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
