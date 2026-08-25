import SwiftData
import SwiftUI

@main
struct EaseFocusApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try EaseFocusStore.makeContainer()
        } catch {
            modelContainer = try! ModelContainer(
                for: FocusItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 640)
        #endif
        .modelContainer(modelContainer)
    }
}
