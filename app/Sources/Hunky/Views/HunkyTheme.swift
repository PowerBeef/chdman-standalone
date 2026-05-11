import AppKit
import Foundation
import SwiftUI

// MARK: - Design tokens
//
// Hunky's register is a retro optical-console workbench for disc archive jobs:
// tactile, game-adjacent, and trustworthy. Blue-tinted Liquid Glass surfaces
// carry state LEDs, disc-bay panels, and queue slots without obscuring file safety.
//
// All colors are OKLCH-derived and converted to sRGB at static-init time, so
// light/dark variants stay perceptually balanced rather than hand-tuned RGB pairs.
// Hunky is dark-only by design. The OKLCH source values are the dark theme.

enum HunkyTheme {

    // MARK: - Surfaces
    enum Surface {
        /// Window backdrop behind glass. Deep console blue.
        static let base = oklchColor(0.105, 0.032, 245)
        /// Raised glass tint for headers and utility groups.
        static let raised = oklchColor(0.30, 0.060, 232, alpha: 0.42)
        /// Resting job-slot glass tint.
        static let row = oklchColor(0.22, 0.052, 235, alpha: 0.36)
        /// Row hover — clearly brighter than resting.
        static let rowHover = oklchColor(0.42, 0.090, 220, alpha: 0.44)
        /// Row selected/active — strong visual contrast.
        static let rowSelected = oklchColor(0.55, 0.115, 210, alpha: 0.46)
        /// Titlebar color hint, used only by legacy callers.
        static let titlebar = oklchColor(0.18, 0.040, 240)
        /// Footer glass tint.
        static let footer = oklchColor(0.18, 0.040, 240, alpha: 0.30)
        /// Inset glass tint for telemetry wells and tracks.
        static let sunken = oklchColor(0.15, 0.036, 244, alpha: 0.52)
        /// Small control/chip glass tint.
        static let control = oklchColor(0.34, 0.070, 224, alpha: 0.34)
        /// Compat alias for running-row tint and sunken progress track.
        static let muted = oklchColor(0.15, 0.036, 244, alpha: 0.52)
        /// Main workbench glass tint.
        static let consolePanel = oklchColor(0.28, 0.070, 230, alpha: 0.34)
        /// Deeper queue-deck glass tint.
        static let consolePanelDeep = oklchColor(0.18, 0.050, 238, alpha: 0.38)
        /// Refractive blue edge highlight.
        static let bevel = oklchColor(0.74, 0.095, 215, alpha: 0.46)
        /// Dim scanline/texture ink.
        static let textureInk = oklchColor(0.72, 0.08, 215, alpha: 0.08)
    }

    // MARK: - Liquid Glass
    enum Glass {
        /// Panel glass: neutral blue tint.
        static let panelTint = oklchColor(0.43, 0.105, 218, alpha: 0.34)
        /// Deep panel glass: cooler indigo for deck background.
        static let panelDeepTint = oklchColor(0.26, 0.080, 238, alpha: 0.40)
        /// Row/slot glass: teal shift distinguishes from panel.
        static let slotTint = oklchColor(0.36, 0.095, 200, alpha: 0.36)
        /// Control/chip glass: violet-shifted for contrast.
        static let controlTint = oklchColor(0.50, 0.110, 240, alpha: 0.28)
        /// Subtle stroke: cool blue hairline.
        static let stroke = oklchColor(0.78, 0.095, 214, alpha: 0.38)
        /// Strong stroke: cyan pop for edges and focus.
        static let strokeStrong = oklchColor(0.86, 0.130, 200, alpha: 0.58)
        /// Glass shadow.
        static let shadow = oklchColor(0.03, 0.028, 245, alpha: 0.50)
    }

    // MARK: - Hairlines
    enum Hairline {
        static let base = oklchColor(0.70, 0.070, 215, alpha: 0.34)
        static let strong = oklchColor(0.82, 0.095, 210, alpha: 0.55)
    }

    // MARK: - Ink
    enum Ink {
        static let primary = oklchColor(0.96, 0.006, 250)
        static let secondary = oklchColor(0.84, 0.012, 250)
        static let tertiary = oklchColor(0.72, 0.014, 250)
        static let quaternary = oklchColor(0.48, 0.016, 250)
    }

    // MARK: - Accents
    enum Accent {
        /// Primary decorative accent: blue-cyan.
        static let base = oklchColor(0.78, 0.155, 210)
        static let soft = oklchColor(0.78, 0.155, 210, alpha: 0.22)
        /// Call-to-action: warmer cyan for prominent buttons.
        static let cta = oklchColor(0.80, 0.165, 200)
        /// Glow tint.
        static let glow = oklchColor(0.70, 0.150, 210, alpha: 0.32)
    }

    // MARK: - Memory Amber
    enum Memory {
        /// Memory-card amber: warm decorative details only.
        static let base = oklchColor(0.78, 0.12, 78)
        static let soft = oklchColor(0.78, 0.12, 78, alpha: 0.16)
    }

    // MARK: - Severity
    enum Severity {
        /// Verified positive: forest green.
        static let verified = oklchColor(0.74, 0.13, 145)
        static let verifiedSoft = oklchColor(0.74, 0.13, 145, alpha: 0.14)
        /// Caution warning: orange (distinct from decorative amber).
        static let caution = oklchColor(0.76, 0.14, 55)
        static let cautionSoft = oklchColor(0.76, 0.14, 55, alpha: 0.16)
        /// Critical error: red.
        static let critical = oklchColor(0.66, 0.16, 25)
        static let criticalSoft = oklchColor(0.66, 0.16, 25, alpha: 0.16)
    }

    // MARK: - Redump
    enum Redump {
        /// Catalog match: violet, reserved for confirmed CRC matches.
        static let base = oklchColor(0.72, 0.13, 285)
        static let soft = oklchColor(0.72, 0.13, 285, alpha: 0.18)
    }

    // MARK: - Platform
    enum Platform {
        static let dreamcast = oklchColor(0.74, 0.12, 210)
        static let psx       = oklchColor(0.78, 0.12, 80)
        static let saturn    = oklchColor(0.68, 0.13, 25)
        static let gameCube  = oklchColor(0.72, 0.13, 285)
        static let cdrom     = oklchColor(0.58, 0.006, 250)
    }

    // MARK: - Backward compatibility aliases

    static var surface: Color { Surface.base }
    static var surfaceRaised: Color { Surface.raised }
    static var surfaceRow: Color { Surface.row }
    static var surfaceRowHover: Color { Surface.rowHover }
    static var surfaceRowSelected: Color { Surface.rowSelected }
    static var titlebarFill: Color { Surface.titlebar }
    static var footerFill: Color { Surface.footer }
    static var surfaceSunken: Color { Surface.sunken }
    static var surfaceControl: Color { Surface.control }
    static var surfaceMuted: Color { Surface.muted }
    static var consolePanel: Color { Surface.consolePanel }
    static var consolePanelDeep: Color { Surface.consolePanelDeep }
    static var consoleBevel: Color { Surface.bevel }
    static var consoleTextureInk: Color { Surface.textureInk }

    static var glassPanelTint: Color { Glass.panelTint }
    static var glassPanelDeepTint: Color { Glass.panelDeepTint }
    static var glassSlotTint: Color { Glass.slotTint }
    static var glassControlTint: Color { Glass.controlTint }
    static var glassStroke: Color { Glass.stroke }
    static var glassStrokeStrong: Color { Glass.strokeStrong }
    static var glassShadow: Color { Glass.shadow }
    static var blueGlow: Color { Accent.glow }

    static var hairline: Color { Hairline.base }
    static var hairlineStrong: Color { Hairline.strong }

    static var inkPrimary: Color { Ink.primary }
    static var inkSecondary: Color { Ink.secondary }
    static var inkTertiary: Color { Ink.tertiary }
    static var inkQuaternary: Color { Ink.quaternary }

    static var accent: Color { Accent.base }
    static var accentSoft: Color { Accent.soft }
    static var accentCTA: Color { Accent.cta }
    static var memoryAmber: Color { Memory.base }
    static var memoryAmberSoft: Color { Memory.soft }
    static var severityVerified: Color { Severity.verified }
    static var severityVerifiedSoft: Color { Severity.verifiedSoft }
    static var severityCaution: Color { Severity.caution }
    static var severityCautionSoft: Color { Severity.cautionSoft }
    static var severityCritical: Color { Severity.critical }
    static var severityCriticalSoft: Color { Severity.criticalSoft }
    static var redump: Color { Redump.base }
    static var redumpSoft: Color { Redump.soft }

    static var platformDreamcast: Color { Platform.dreamcast }
    static var platformPSX: Color { Platform.psx }
    static var platformSaturn: Color { Platform.saturn }
    static var platformGameCube: Color { Platform.gameCube }
    static var platformCDROM: Color { Platform.cdrom }

    static func severityColor(_ severity: RiskSeverity) -> Color {
        switch severity {
        case .notice:   return Ink.secondary
        case .caution:  return Severity.caution
        case .critical: return Severity.critical
        }
    }
}

// MARK: - Typography tokens
//
// SF Pro for UI body. Mono is reserved for telemetry: CRC32 fingerprints,
// formatted sizes, ETA / throughput, and `chdman` raw output inside the
// Info / Log sheets. Filenames stay proportional.

enum HunkyType {
    /// Window/section-level display.
    static let display: Font = .system(size: 22, weight: .bold, design: .default)
    /// Empty state and major section headlines.
    static let headline: Font = .system(size: 18, weight: .bold, design: .default)
    /// Row titles, sheet headers, module labels.
    static let title: Font = .system(size: 15, weight: .semibold, design: .default)
    /// Body text - proportional system face.
    static let body: Font = .system(size: 13, weight: .regular, design: .default)
    /// Callout-level emphasis.
    static let callout: Font = .system(size: 12.5, weight: .regular, design: .default)
    /// Section/module labels ("Save path", "Ready Check").
    static let sectionTitle: Font = .system(size: 12, weight: .semibold, design: .default)
    /// Status emphasis text.
    static let status: Font = .system(size: 11.5, weight: .medium, design: .default)
    /// Captions, status labels.
    static let label: Font = .system(size: 11.5, weight: .regular, design: .default)
    /// Smallest tier. Chips, micro-labels.
    static let label2: Font = .system(size: 10.5, weight: .regular, design: .default)
    /// Telemetry: CRC, size, ETA, throughput, raw chdman output.
    static let mono: Font = .system(size: 10.5, weight: .regular, design: .monospaced)
    /// Micro mono for progress labels.
    static let micro: Font = .system(size: 9, weight: .semibold, design: .monospaced)
    /// Format chip text (CUE / GDI / TOC / ISO / CHD).
    static let formatChip: Font = .system(size: 10.5, weight: .medium, design: .default)
}

// MARK: - Motion tokens

enum HunkyMotion {
    /// Snap transition for row state changes and disclosure expansion.
    /// Honor `accessibilityReduceMotion` at the call site by passing `nil` instead.
    static let snap: Animation = .easeOut(duration: 0.18)
    /// Period of the running-progress shimmer sweep (seconds).
    static let shimmerPeriod: TimeInterval = 1.6
    /// Period of the in-row spinning-disc progress ring (seconds).
    static let progressSpinPeriod: TimeInterval = 1.4
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

/// Convert OKLCH (L 0...1, C 0...~0.4, h 0...360 deg) to gamma-encoded sRGB in 0...1.
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
