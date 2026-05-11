import Foundation
import Observation

/// Persistent user preferences for Hunky.
///
/// All values are backed by `UserDefaults` and observed via `@Observable`
/// so any view can bind to them directly.
@Observable
final class AppSettings {
    private let defaults: UserDefaults
    private let prefix = "com.powerbeef.Hunky.settings."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var outputDirectory: URL? {
        get {
            guard let string = defaults.string(forKey: key("outputDirectory")) else { return nil }
            return URL(fileURLWithPath: string)
        }
        set {
            if let path = newValue?.path(percentEncoded: false) {
                defaults.set(path, forKey: key("outputDirectory"))
            } else {
                defaults.removeObject(forKey: key("outputDirectory"))
            }
        }
    }

    var soundEnabled: Bool {
        get { defaults.bool(forKey: key("soundEnabled"), defaultValue: true) }
        set { defaults.set(newValue, forKey: key("soundEnabled")) }
    }

    var autoRetryFailed: Bool {
        get { defaults.bool(forKey: key("autoRetryFailed"), defaultValue: false) }
        set { defaults.set(newValue, forKey: key("autoRetryFailed")) }
    }

    var showPlatformBadges: Bool {
        get { defaults.bool(forKey: key("showPlatformBadges"), defaultValue: true) }
        set { defaults.set(newValue, forKey: key("showPlatformBadges")) }
    }

    var confirmBeforeRun: Bool {
        get { defaults.bool(forKey: key("confirmBeforeRun"), defaultValue: true) }
        set { defaults.set(newValue, forKey: key("confirmBeforeRun")) }
    }

    var defaultCreateAction: Action {
        get {
            guard let raw = defaults.string(forKey: key("defaultCreateAction")),
                  let action = Action(rawValue: raw) else {
                return .createCD
            }
            return action
        }
        set { defaults.set(newValue.rawValue, forKey: key("defaultCreateAction")) }
    }

    var defaultChdAction: Action {
        get {
            guard let raw = defaults.string(forKey: key("defaultChdAction")),
                  let action = Action(rawValue: raw) else {
                return .extractCD
            }
            return action
        }
        set { defaults.set(newValue.rawValue, forKey: key("defaultChdAction")) }
    }

    func defaultAction(for kind: InputKind) -> Action {
        let stored: Action
        switch kind {
        case .cdImage:
            stored = defaultCreateAction
        case .chd:
            stored = defaultChdAction
        }
        return Action.defaultActions(for: kind).contains(stored) ? stored : Action.defaultAction(for: kind)
    }

    private func key(_ name: String) -> String {
        "\(prefix)\(name)"
    }
}

private extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil { return defaultValue }
        return bool(forKey: key)
    }
}
