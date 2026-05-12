import AppKit
import SwiftUI

struct ToolbarFilterSearchGroup<MenuItems: View>: View {
    @Binding var text: String
    let placeholder: String
    let menuItems: () -> MenuItems

    init(
        text: Binding<String>,
        placeholder: String = "Filter queue",
        @ViewBuilder menuItems: @escaping () -> MenuItems
    ) {
        _text = text
        self.placeholder = placeholder
        self.menuItems = menuItems
    }

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                menuItems()
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .menuIndicator(.hidden)
            .help("Queue filters and actions")
            .accessibilityLabel("Queue filters and actions")

            NativeToolbarSearchField(text: $text, placeholder: placeholder)
                .frame(width: HunkyLayout.toolbarSearchWidth, height: 28)
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}

private struct NativeToolbarSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchFieldAction(_:))
        field.controlSize = .regular
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.text = $text
        field.focusRingType = .none
        if field.stringValue != text {
            field.stringValue = text
        }
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func searchFieldAction(_ sender: NSSearchField) {
            updateText(sender.stringValue)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            updateText(field.stringValue)
        }

        private func updateText(_ value: String) {
            if text.wrappedValue != value {
                text.wrappedValue = value
            }
        }
    }
}
