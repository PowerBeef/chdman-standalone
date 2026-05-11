import SwiftUI

struct QueueSearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onClear: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(HunkyType.label)
                .foregroundStyle(HunkyTheme.Ink.tertiary)

            TextField(placeholder, text: $text)
                .font(HunkyType.callout)
                .textFieldStyle(.plain)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(HunkyType.callout)
                        .foregroundStyle(HunkyTheme.Ink.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(width: 220)
        .liquidGlassChip(tint: HunkyTheme.Glass.controlTint, cornerRadius: 6)
    }
}
