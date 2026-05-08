import SwiftUI

// MARK: - Settings scene

struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text("chdman 0.287, arm64")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Hunky")
            } footer: {
                Text("Runtime defaults are shown here for clarity. Per-run output is controlled from the toolbar or Queue menu.")
                    .foregroundStyle(.secondary)
            }

            Section("Output") {
                LabeledContent("Default location") {
                    Text("Same folder as source")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Name collisions") {
                    Text("Add numeric suffix")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Overwrite policy") {
                    Label("Never overwrite", systemImage: "lock.fill")
                        .foregroundStyle(HunkyTheme.inkSecondary)
                }
            }

            Section("Audit") {
                LabeledContent("Redump audit") {
                    Text("Enabled for referenced disc sheets")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Critical issues") {
                    Text("Require confirmation before run")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Bundled catalogs") {
                    HStack(spacing: 6) {
                        SettingsPlatformChip(text: "PS1", color: HunkyTheme.platformPSX)
                        SettingsPlatformChip(text: "Saturn", color: HunkyTheme.platformSaturn)
                        SettingsPlatformChip(text: "Dreamcast", color: HunkyTheme.platformDreamcast)
                    }
                }
            }

            Section("Compression") {
                LabeledContent("Create CHD") {
                    Text("Uses chdman defaults")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Compressors") {
                    Text("cdlz, cdzl, cdfl")
                        .font(HunkyType.mono)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(HunkyTheme.surface)
        .frame(minWidth: 540, minHeight: 440)
    }
}

// MARK: - Platform chip

private struct SettingsPlatformChip: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(HunkyType.formatChip)
                .foregroundStyle(HunkyTheme.inkSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(HunkyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(HunkyTheme.hairline, lineWidth: 1)
        )
    }
}
