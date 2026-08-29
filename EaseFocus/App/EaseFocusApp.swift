import SwiftData
import SwiftUI

@main
struct EaseFocusApp: App {
    private let modelContainer: ModelContainer?
    @State private var timer = FocusTimerController()
    #if os(macOS)
    @NSApplicationDelegateAdaptor(EaseFocusAppDelegate.self) private var appDelegate
    #endif

    init() {
        modelContainer = try? EaseFocusStore.makeContainer()
        #if os(macOS)
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        #endif
    }

    var body: some Scene {
        #if os(macOS)
        Window("EaseFocus", id: EaseFocusSceneID.main) {
            root
        }
        .defaultSize(width: 480, height: 640)
        .restorationBehavior(.disabled)
        .handlesExternalEvents(matching: [])
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        #else
        WindowGroup {
            root
        }
        .handlesExternalEvents(matching: Set([EaseFocusSceneID.main]))
        #endif
    }

    @ViewBuilder
    private var root: some View {
        if let modelContainer {
            RootView()
                .modelContainer(modelContainer)
                .environment(timer)
        } else {
            PersistenceErrorView()
        }
    }
}
