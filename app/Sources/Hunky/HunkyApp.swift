import SwiftUI

@main
struct HunkyApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            HunkyCommands()
        }

        Settings {
            SettingsView(settings: settings)
        }
    }
}
