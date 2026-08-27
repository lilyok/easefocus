import SwiftData
import SwiftUI

@main
struct EaseFocusApp: App {
    private let modelContainer: ModelContainer?

    init() {
        modelContainer = try? EaseFocusStore.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                RootView()
                    .modelContainer(modelContainer)
            } else {
                PersistenceErrorView()
            }
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 640)
        #endif
    }
}
