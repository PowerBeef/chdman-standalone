import SwiftUI

// MARK: - Settings scene
//
// macOS-native separate Settings window opened via ⌘, or Hunky → Settings…
// Three sections — Output, Audit, Compression — each rendered as the
// design canvas's grouped list cells. New preference toggles persist via
// @AppStorage; the actual runtime wiring (e.g. honoring `verifyAgainstRedump`
// from the audit pipeline) is a separate feature project — the controls
// here are visually correct and persist between launches.

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Section header
                HStack(alignment: .firstTextBaseline) {
                    Text("Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HunkyTheme.inkPrimary)
                    Spacer()
                    Text("chdman 0.287 · arm64")
                        .font(.system(size: 11))
                        .foregroundStyle(HunkyTheme.inkTertiary)
                }
                .padding(.bottom, 4)

                outputSection
                auditSection
                compressionSection
            }
            .padding(20)
        }
        .background(HunkyTheme.surface)
        .frame(minWidth: 540, minHeight: 520)
    }

    // MARK: Output

    @AppStorage("hunky.preferredOutputDirectory") private var preferredOutputPath: String = ""
    @AppStorage("hunky.useSourceFolder") private var useSourceFolder: Bool = false
    @AppStorage("hunky.collisionBehavior") private var collisionBehavior: String = "suffix"

    @ViewBuilder
    private var outputSection: some View {
        SettingsGroup(header: "Output") {
            SettingsRow(
                label: "Output folder",
                desc: "Where created CHDs land. Source folder is used per-item if unset."
            ) {
                MonoValueLabel(text: preferredOutputPath.isEmpty ? "Same folder as source" : preferredOutputPath, systemImage: "folder")
            }
            SettingsRow(
                label: "Use source folder",
                desc: "Place each output next to its source instead of the global folder."
            ) {
                HunkyToggle(isOn: $useSourceFolder)
            }
            SettingsRow(
                label: "On name collision",
                desc: "Hunky never overwrites — choose how to disambiguate."
            ) {
                HunkySegment(
                    selection: $collisionBehavior,
                    options: [("suffix", "Suffix"), ("skip", "Skip"), ("ask", "Ask")]
                )
            }
        }
    }

    // MARK: Audit

    @AppStorage("hunky.verifyAgainstRedump") private var verifyAgainstRedump: Bool = true
    @AppStorage("hunky.blockRunOnCritical") private var blockRunOnCritical: Bool = true

    @ViewBuilder
    private var auditSection: some View {
        SettingsGroup(header: "Audit") {
            SettingsRow(
                label: "Verify against Redump",
                desc: "Hash referenced tracks and match against bundled PS1, Saturn, Dreamcast catalogs."
            ) {
                HunkyToggle(isOn: $verifyAgainstRedump)
            }
            SettingsRow(
                label: "Block run on critical issues",
                desc: "Show preflight sheet if any disc is missing references or has CRC mismatches."
            ) {
                HunkyToggle(isOn: $blockRunOnCritical)
            }
            SettingsRow(
                label: "Bundled catalogs",
                desc: "Offline DATs ship with the app. No network calls."
            ) {
                HStack(spacing: 4) {
                    SettingsPlatformChip(text: "PS1", color: HunkyTheme.platformPSX)
                    SettingsPlatformChip(text: "Saturn", color: HunkyTheme.platformSaturn)
                    SettingsPlatformChip(text: "Dreamcast", color: HunkyTheme.platformDreamcast)
                }
            }
        }
    }

    // MARK: Compression

    @AppStorage("hunky.hunklen") private var hunklen: String = "19"

    @ViewBuilder
    private var compressionSection: some View {
        SettingsGroup(header: "Compression") {
            SettingsRow(
                label: "Compressors",
                desc: "Codecs passed to chdman. Default matches MAME 0.287."
            ) {
                MonoValueLabel(text: "cdlz, cdzl, cdfl", systemImage: nil)
            }
            SettingsRow(
                label: "Hunklen",
                desc: "Sector grouping. Higher = smaller CHD, slower."
            ) {
                HunkySegment(
                    selection: $hunklen,
                    options: [("0", "0"), ("19", "19"), ("32", "32"), ("64", "64")]
                )
            }
        }
    }
}

// MARK: - Group container

private struct SettingsGroup<Content: View>: View {
    let header: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HunkyTheme.inkPrimary)
            VStack(spacing: 0) {
                content
            }
            .background(HunkyTheme.surfaceRow, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HunkyTheme.hairline, lineWidth: 1)
            )
        }
    }
}

// MARK: - Row

private struct SettingsRow<Control: View>: View {
    let label: String
    let desc: String
    @ViewBuilder let control: Control

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(HunkyTheme.inkPrimary)
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundStyle(HunkyTheme.inkTertiary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                control
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(HunkyTheme.hairline)
                .frame(height: 1)
        }
    }
}

// MARK: - Mono value label (e.g., compressors list, output path)

private struct MonoValueLabel: View {
    let text: String
    let systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(HunkyTheme.inkTertiary)
            }
            Text(text)
                .font(HunkyType.mono)
                .foregroundStyle(HunkyTheme.inkSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: 240, alignment: .leading)
        .background(HunkyTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(HunkyTheme.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Custom toggle

private struct HunkyToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? HunkyTheme.severityVerified : HunkyTheme.surfaceControl)
                    .frame(width: 36, height: 20)
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .padding(.horizontal, 2)
                    .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
            }
            .animation(.easeOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Custom segmented control

private struct HunkySegment: View {
    @Binding var selection: String
    let options: [(value: String, label: String)]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { opt in
                Button {
                    selection = opt.value
                } label: {
                    Text(opt.label)
                        .font(.system(size: 11))
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .foregroundStyle(selection == opt.value ? HunkyTheme.inkPrimary : HunkyTheme.inkSecondary)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(selection == opt.value ? HunkyTheme.surfaceRaised : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(HunkyTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(HunkyTheme.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Platform chip (settings-scoped, tinted color from token)

private struct SettingsPlatformChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(HunkyType.formatChip)
            .tracking(0.4)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(Color(red: 0.05, green: 0.05, blue: 0.05))
            .background(color, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}
