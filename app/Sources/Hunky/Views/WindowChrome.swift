import AppKit
import SwiftUI

// MARK: - Run / summary state
//
// ContentView computes these from the queue's state and feeds them to the
// toolbar state items (run pill, summary chip).

enum HunkyRunState {
    /// Queue is empty.
    case none
    /// Queue has items, idle.
    case idle
    /// At least one job is in flight.
    case running
}

enum HunkySummaryKind {
    case ready
    case running
    case warn
}

struct HunkySummary {
    let kind: HunkySummaryKind
    let text: String
}

// MARK: - Pulsing dot

/// Status dot used in the toolbar summary chip when the queue is running.
/// Honors `accessibilityReduceMotion`.
struct PulsingDot: View {
    let color: Color
    let soft: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .background(
                Circle().fill(soft).frame(width: 11, height: 11)
            )
            .opacity(reduceMotion ? 1 : (animate ? 1.0 : 0.45))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: HunkyMotion.runningPulsePeriod / 2).repeatForever(autoreverses: true)
                ) {
                    animate = true
                }
            }
    }
}

// MARK: - Footer

struct HunkyFooter<Left: View, Right: View>: View {
    let left: Left
    let right: Right

    init(@ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.left = left()
        self.right = right()
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) { left }
            Spacer(minLength: 12)
            HStack(spacing: 12) { right }
        }
        .font(.system(size: 11))
        .foregroundStyle(HunkyTheme.inkTertiary)
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(HunkyTheme.footerFill)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(HunkyTheme.hairline)
                .frame(height: 1)
        }
    }
}

/// A right-aligned mono path label for the footer.
struct HunkyFooterPath: View {
    let text: String

    var body: some View {
        Text(text)
            .font(HunkyType.mono)
            .foregroundStyle(HunkyTheme.inkSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
