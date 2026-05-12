import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "terminal")
                }
        }
        .frame(width: 480, height: 360)
        .padding()
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default output folder")
                            .font(HunkyType.body).fontWeight(.semibold)
                        Text(settings.outputDirectory?.path(percentEncoded: false) ?? "Same folder as source")
                            .font(HunkyType.mono)
                            .foregroundStyle(HunkyTheme.Ink.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Choose…") {
                        if let url = FilePicker.pickOutputDirectory() {
                            settings.outputDirectory = url
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    if settings.outputDirectory != nil {
                        Button {
                            settings.outputDirectory = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(HunkyTheme.Ink.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Picker("Default action for CD images", selection: $settings.defaultCreateAction) {
                    ForEach(Action.defaultActions(for: .cdImage)) { action in
                        Text(action.label).tag(action)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Default action for CHD files", selection: $settings.defaultChdAction) {
                    ForEach(Action.defaultActions(for: .chd)) { action in
                        Text(action.label).tag(action)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Play sound on completion", isOn: $settings.soundEnabled)
                Toggle("Confirm before running queue", isOn: $settings.confirmBeforeRun)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Form {
            Section {
                Toggle("Show platform in queue", isOn: $settings.showPlatformBadges)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Section {
                Toggle("Auto-retry failed items", isOn: $settings.autoRetryFailed)
            }
        }
        .formStyle(.grouped)
    }
}
