import SwiftUI

@main
struct HunkyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            HunkyCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
