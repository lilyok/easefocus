import SwiftData
import SwiftUI

@main
struct EaseFocusApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 640)
        #endif
        .modelContainer(for: FocusItem.self)
    }
}
