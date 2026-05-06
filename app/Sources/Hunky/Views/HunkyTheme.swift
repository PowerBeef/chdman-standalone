import AppKit
import SwiftUI

enum HunkyTheme {
    static let surface = adaptiveColor(
        light: RGB(0.968, 0.956, 0.929),
        dark: RGB(0.126, 0.118, 0.108)
    )
    static let raisedSurface = adaptiveColor(
        light: RGB(0.988, 0.980, 0.956),
        dark: RGB(0.162, 0.152, 0.139)
    )
    static let recessedSurface = adaptiveColor(
        light: RGB(0.936, 0.920, 0.890),
        dark: RGB(0.098, 0.092, 0.085)
    )
    static let hairline = adaptiveColor(
        light: RGB(0.760, 0.724, 0.672),
        dark: RGB(0.310, 0.286, 0.252)
    )
    static let retroBlue = adaptiveColor(
        light: RGB(0.075, 0.392, 0.706),
        dark: RGB(0.338, 0.620, 0.918)
    )
    static let amber = adaptiveColor(
        light: RGB(0.740, 0.410, 0.050),
        dark: RGB(0.950, 0.640, 0.210)
    )
    static let verifiedGreen = adaptiveColor(
        light: RGB(0.150, 0.520, 0.290),
        dark: RGB(0.420, 0.760, 0.520)
    )
    static let failureRed = adaptiveColor(
        light: RGB(0.750, 0.180, 0.150),
        dark: RGB(0.950, 0.410, 0.360)
    )
    static let subtleInk = adaptiveColor(
        light: RGB(0.310, 0.285, 0.245),
        dark: RGB(0.780, 0.742, 0.690)
    )

    static func severityColor(_ severity: RiskSeverity) -> Color {
        switch severity {
        case .notice: return .secondary
        case .caution: return amber
        case .critical: return failureRed
        }
    }

    private struct RGB {
        let red: Double
        let green: Double
        let blue: Double

        init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    private static func adaptiveColor(light: RGB, dark: RGB) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(
                    calibratedRed: dark.red,
                    green: dark.green,
                    blue: dark.blue,
                    alpha: 1
                )
            }
            return NSColor(
                calibratedRed: light.red,
                green: light.green,
                blue: light.blue,
                alpha: 1
            )
        })
    }
}
