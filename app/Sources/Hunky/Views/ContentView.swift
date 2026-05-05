import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var queue = QueueController()
    @State private var infoItem: FileItem?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

            Divider()

            if queue.items.isEmpty {
                DropZone(isCompact: false) { urls in
                    queue.add(urls: urls)
                }
                .padding(20)
            } else {
                queueList
            }

            Divider()
            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(minWidth: 620, minHeight: 460)
        .sheet(item: $infoItem) { item in
            InfoSheet(item: item)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "opticaldisc.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Hunky")
                    .font(.title3.weight(.semibold))
                Text("Convert and inspect CHD disk images")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !queue.items.isEmpty {
                Button {
                    queue.clear()
                } label: {
                    Label("Clear finished", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(!queue.items.contains(where: isFinished))
            }
        }
    }

    private var queueList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(queue.items) { item in
                    QueueRow(
                        item: item,
                        isQueueRunning: queue.isRunning,
                        onRemove: { queue.remove(item) },
                        onShowInfo: { infoItem = item }
                    )
                }
                DropZone(isCompact: true) { urls in
                    queue.add(urls: urls)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            outputDirControl
            Spacer()
            primaryButton
        }
    }

    private var outputDirControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text("Output:")
                .foregroundStyle(.secondary)
            Text(outputLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 220, alignment: .leading)
            Button {
                pickOutputDirectory()
            } label: {
                Text(queue.outputDirectory == nil ? "Choose…" : "Change…")
            }
            if queue.outputDirectory != nil {
                Button {
                    queue.outputDirectory = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Reset to source folder")
            }
        }
        .font(.callout)
    }

    private var outputLabel: String {
        if let dir = queue.outputDirectory {
            return dir.path(percentEncoded: false)
        }
        return "Same folder as source"
    }

    @ViewBuilder
    private var primaryButton: some View {
        if queue.isRunning {
            Button(role: .destructive) {
                queue.cancel()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .frame(minWidth: 80)
            }
            .controlSize(.large)
            .keyboardShortcut(".", modifiers: [.command])
        } else {
            Button {
                queue.start()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .frame(minWidth: 80)
            }
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!queue.items.contains(where: isPending))
            .buttonStyle(.borderedProminent)
        }
    }

    private func pickOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            queue.outputDirectory = url
        }
    }

    private func isFinished(_ item: FileItem) -> Bool {
        switch item.status {
        case .done, .failed, .cancelled: return true
        case .idle, .running:            return false
        }
    }

    private func isPending(_ item: FileItem) -> Bool {
        if case .idle = item.status { return true }
        return false
    }
}

private struct InfoSheet: View {
    let item: FileItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName).font(.headline)
                    Text("CHD info").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            Divider()
            ScrollView {
                Text(item.infoOutput ?? "(no output)")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
        .frame(minWidth: 560, minHeight: 380)
    }
}
