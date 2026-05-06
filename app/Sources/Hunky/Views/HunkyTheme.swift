import AppKit
import Foundation
import SwiftUI

// MARK: - Design tokens
//
// Hunky's register is "cartridge / disc archivist" — manifest-first, audit-as-feature,
// integrity tooling. Tinted near-black surfaces (oklch hue 240, slight cool-cyan
// undertone) carry saturated game-tool accents. Severity colors share a chroma
// family. Platform spines color-code each disc by console.
//
// All colors are OKLCH-derived and converted to sRGB at static-init time, so
// light/dark variants stay perceptually balanced rather than hand-tuned RGB pairs.
// Hunky is dark-only by design — the OKLCH source values are the dark theme.

enum HunkyTheme {
    // MARK: - Surfaces
    /// Window background. Tinted near-black.
    static let surface = oklchColor(0.18, 0.012, 240)
    /// Raised areas: titlebar, popovers, settings groups.
    static let surfaceRaised = oklchColor(0.215, 0.014, 240)
    /// Row resting background (slight bump above surface).
    static let surfaceRow = oklchColor(0.20, 0.013, 240)
    /// Row hover background.
    static let surfaceRowHover = oklchColor(0.235, 0.015, 240)
    /// Row selected/active background (warmer toward accent).
    static let surfaceRowSelected = oklchColor(0.235, 0.018, 220)
    /// Titlebar fill.
    static let titlebarFill = oklchColor(0.225, 0.014, 240)
    /// Footer fill (slightly darker than surface).
    static let footerFill = oklchColor(0.165, 0.012, 240)
    /// Inset / sunken areas (column header, telemetry chips).
    static let surfaceSunken = oklchColor(0.16, 0.012, 240)
    /// Subtle button background inside groups.
    static let surfaceControl = oklchColor(0.24, 0.012, 240)
    /// Compat alias used by mid-overhaul callers (running-row tint, sunken progress track).
    /// Resolves to the same value as `surfaceSunken`.
    static let surfaceMuted = oklchColor(0.16, 0.012, 240)

    // MARK: - Hairlines
    static let hairline = oklchColor(0.32, 0.012, 240, alpha: 0.6)
    static let hairlineStrong = oklchColor(0.38, 0.012, 240, alpha: 0.85)

    // MARK: - Ink
    static let inkPrimary = oklchColor(0.96, 0.005, 240)
    static let inkSecondary = oklchColor(0.74, 0.008, 240)
    static let inkTertiary = oklchColor(0.55, 0.010, 240)
    static let inkQuaternary = oklchColor(0.42, 0.012, 240)

    // MARK: - Accents (saturated game-tool register)
    /// Primary action: cyan.
    static let accent = oklchColor(0.74, 0.15, 220)
    static let accentSoft = oklchColor(0.74, 0.15, 220, alpha: 0.16)
    /// Verified positive: forest green.
    static let severityVerified = oklchColor(0.78, 0.18, 145)
    static let severityVerifiedSoft = oklchColor(0.78, 0.18, 145, alpha: 0.14)
    /// Caution warning: amber.
    static let severityCaution = oklchColor(0.82, 0.15, 80)
    static let severityCautionSoft = oklchColor(0.82, 0.15, 80, alpha: 0.16)
    /// Critical error: red.
    static let severityCritical = oklchColor(0.68, 0.22, 25)
    static let severityCriticalSoft = oklchColor(0.68, 0.22, 25, alpha: 0.16)
    /// Redump catalog match: violet — reserved for confirmed Redump CRC matches.
    static let redump = oklchColor(0.72, 0.18, 295)
    static let redumpSoft = oklchColor(0.72, 0.18, 295, alpha: 0.16)

    // MARK: - Platform spines
    /// Color-coded leading edge of each queue row, keyed off detected platform.
    static let platformDreamcast = oklchColor(0.74, 0.16, 250)
    static let platformPSX       = oklchColor(0.78, 0.15, 80)
    static let platformSaturn    = oklchColor(0.70, 0.20, 25)
    static let platformGameCube  = oklchColor(0.72, 0.18, 295)
    static let platformCDROM     = oklchColor(0.55, 0.012, 240)

    static func severityColor(_ severity: RiskSeverity) -> Color {
        switch severity {
        case .notice:   return inkSecondary
        case .caution:  return severityCaution
        case .critical: return severityCritical
        }
    }
}

// MARK: - Typography tokens
//
// SF Pro for UI body. Mono is reserved for telemetry — CRC32 fingerprints,
// formatted sizes, ETA / throughput, and `chdman` raw output inside the
// Info / Log sheets. Filenames stay proportional.

enum HunkyType {
    /// Display headlines: queue overview, sheet titles.
    static let title: Font = .system(size: 15, weight: .semibold, design: .default)
    /// Body text — proportional system face.
    static let body: Font = .system(size: 13, weight: .regular, design: .default)
    /// Captions.
    static let label: Font = .system(size: 11.5, weight: .regular, design: .default)
    /// Smallest tier. Chips, micro-labels.
    static let label2: Font = .system(size: 10.5, weight: .regular, design: .default)
    /// Telemetry: CRC, size, ETA, throughput, raw chdman output.
    static let mono: Font = .system(size: 10.5, weight: .regular, design: .monospaced)
    /// Format chip text (CUE / GDI / TOC / ISO / CHD).
    static let formatChip: Font = .system(size: 9.5, weight: .semibold, design: .monospaced)
}

// MARK: - Motion tokens

enum HunkyMotion {
    /// Snap transition for row state changes and disclosure expansion.
    /// Honor `accessibilityReduceMotion` at the call site by passing `nil` instead.
    static let snap: Animation = .easeOut(duration: 0.18)
    /// Period of the running-progress shimmer sweep (seconds).
    static let shimmerPeriod: TimeInterval = 1.6
    /// Period of the empty-state hero disc spin (seconds, full rotation).
    static let heroSpinPeriod: TimeInterval = 22.0
    /// Period of the in-row spinning-disc progress ring (seconds).
    static let progressSpinPeriod: TimeInterval = 1.4
    /// Pulse period of the running-state status dot in the titlebar (seconds).
    static let runningPulsePeriod: TimeInterval = 1.4
}

// MARK: - OKLCH → sRGB

private struct LinearSRGB {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
}

/// Convert an OKLCH triple to a SwiftUI `Color` in calibrated sRGB.
/// `alpha` defaults to 1 so opaque tokens stay readable.
private func oklchColor(_ L: Double, _ C: Double, _ h: Double, alpha: Double = 1.0) -> Color {
    let srgb = oklchToSRGB(L: L, C: C, h: h)
    return Color(.sRGB,
                 red: Double(srgb.r),
                 green: Double(srgb.g),
                 blue: Double(srgb.b),
                 opacity: alpha)
}

/// Convert OKLCH (L 0–1, C 0–~0.4, h 0–360°) to gamma-encoded sRGB in 0–1.
/// Implements Björn Ottosson's OKLab → linear sRGB transform, then sRGB
/// gamma encoding. Out-of-gamut values are clamped per channel.
private func oklchToSRGB(L: Double, C: Double, h: Double) -> LinearSRGB {
    let hRad = h * .pi / 180
    let a = C * cos(hRad)
    let b = C * sin(hRad)

    let lPrime = L + 0.3963377774 * a + 0.2158037573 * b
    let mPrime = L - 0.1055613458 * a - 0.0638541728 * b
    let sPrime = L - 0.0894841775 * a - 1.2914855480 * b

    let lLinear = lPrime * lPrime * lPrime
    let mLinear = mPrime * mPrime * mPrime
    let sLinear = sPrime * sPrime * sPrime

    let linearR =  4.0767416621 * lLinear - 3.3077115913 * mLinear + 0.2309699292 * sLinear
    let linearG = -1.2684380046 * lLinear + 2.6097574011 * mLinear - 0.3413193965 * sLinear
    let linearB = -0.0041960863 * lLinear - 0.7034186147 * mLinear + 1.7076147010 * sLinear

    return LinearSRGB(
        r: gammaEncode(linearR),
        g: gammaEncode(linearG),
        b: gammaEncode(linearB)
    )
}

private func gammaEncode(_ linear: Double) -> CGFloat {
    let clamped = max(0.0, min(1.0, linear))
    let encoded: Double
    if clamped <= 0.0031308 {
        encoded = 12.92 * clamped
    } else {
        encoded = 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
    }
    return CGFloat(max(0.0, min(1.0, encoded)))
}
