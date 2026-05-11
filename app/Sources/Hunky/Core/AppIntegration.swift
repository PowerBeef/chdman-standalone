import AppKit
import Foundation
import UserNotifications

@MainActor
enum AppIntegration {
    private static var notificationAuthorizationRequested = false
    private static var notificationAuthorized = false

    static func requestNotificationAuthorization() {
        guard !notificationAuthorizationRequested else { return }
        notificationAuthorizationRequested = true
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                notificationAuthorized = granted
            }
        }
    }

    static func postQueueCompletion(summary: RunSummary) {
        updateDockBadge(summary: summary)

        guard summary.hasWork else { return }

        let content = UNMutableNotificationContent()
        if summary.isClean {
            content.title = "Queue Complete"
            content.body = summary.successBreakdown
            content.sound = .default
        } else {
            content.title = "Queue Finished with Issues"
            var parts: [String] = []
            if summary.failed > 0 { parts.append("\(summary.failed) failed") }
            if summary.cancelled > 0 { parts.append("\(summary.cancelled) cancelled") }
            content.body = parts.joined(separator: ", ")
            content.sound = .defaultCritical
        }

        let request = UNNotificationRequest(
            identifier: "queue-completion-\(summary.startedAt.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func updateDockBadge(running: Int = 0, pending: Int = 0) {
        if running > 0 {
            NSApp.dockTile.badgeLabel = "\(running)"
        } else if pending > 0 {
            NSApp.dockTile.badgeLabel = "\(pending)"
        } else {
            NSApp.dockTile.badgeLabel = nil
        }
    }

    static func updateDockBadge(summary: RunSummary) {
        NSApp.dockTile.badgeLabel = nil
    }

    static func playCompletionSound(success: Bool) {
        guard let sound = success ? NSSound(named: "Glass") : NSSound(named: "Basso") else { return }
        sound.play()
    }
}
