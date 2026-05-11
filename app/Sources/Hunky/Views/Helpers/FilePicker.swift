import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum FilePicker {
    static func pickFiles(allowedExtensions: [String] = ["chd", "cue", "gdi", "iso", "toc"]) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = allowedExtensions.compactMap { UTType(filenameExtension: $0) ?? .data }
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    static func pickOutputDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
