import SwiftUI

@main
struct HunkyApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
        }
        .defaultSize(width: HunkyLayout.windowMinWidth, height: HunkyLayout.windowMinHeight)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            HunkyCommands()
        }

        Settings {
            SettingsView(settings: settings)
        }
    }
}
