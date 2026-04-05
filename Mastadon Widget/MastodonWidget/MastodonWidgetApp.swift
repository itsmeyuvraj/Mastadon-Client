import SwiftUI

@main
struct MastodonWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No visible window — the app lives entirely in the menu bar.
        // Settings scene is required to satisfy SwiftUI App protocol on macOS.
        Settings {
            EmptyView()
        }
    }
}
