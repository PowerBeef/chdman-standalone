import SwiftUI
import UniformTypeIdentifiers

struct DropZone: View {
    let isCompact: Bool
    let onDrop: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        Button(action: pickFiles) {
            ZStack {
                RoundedRectangle(cornerRadius: isCompact ? 8 : 12, style: .continuous)
                    .strokeBorder(
                        isTargeted ? HunkyTheme.retroBlue : HunkyTheme.hairline,
                        style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [6, 5])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: isCompact ? 8 : 12, style: .continuous)
                            .fill(isTargeted ? HunkyTheme.retroBlue.opacity(0.12) : HunkyTheme.recessedSurface)
                    )

                content
                    .padding(isCompact ? 12 : 32)
            }
            .frame(minHeight: isCompact ? 64 : 220)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
        .animation(.easeOut(duration: 0.15), value: isTargeted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isCompact ? "Add more disc files or folders" : "Add disc files or folders")
        .accessibilityHint("Opens a file picker. You can also drop cue, gdi, toc, iso, chd files, or folders.")
    }

    @ViewBuilder
    private var browsePill: some View {
        HStack(spacing: 5) {
            Image(systemName: "folder.badge.plus")
                .imageScale(.small)
            Text("Browse...")
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(HunkyTheme.retroBlue)
        .padding(.horizontal, isCompact ? 8 : 14)
        .padding(.vertical, isCompact ? 4 : 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(HunkyTheme.retroBlue.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HunkyTheme.retroBlue.opacity(0.30), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        if isCompact {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(HunkyTheme.retroBlue)
                Text("Drop more files or folders")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                browsePill
            }
        } else {
            VStack(spacing: 14) {
                Image(systemName: "opticaldiscdrive")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(HunkyTheme.retroBlue)
                Text("Drop discs here")
                    .font(.title3.weight(.semibold))
                Text("CUE, GDI, TOC, ISO, CHD, or a folder")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                browsePill
                    .padding(.top, 4)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for p in providers {
            group.enter()
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.isFileURL {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            lock.lock()
            let dropped = urls
            lock.unlock()
            if !dropped.isEmpty { onDrop(dropped) }
        }
        return true
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
