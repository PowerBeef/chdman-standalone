import SwiftUI

@main
struct HunkyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        // Native macOS unified toolbar: traffic lights and toolbar items
        // sit on the same eye-line by OS guarantee.
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            HunkyCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
