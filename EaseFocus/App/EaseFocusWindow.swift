#if os(macOS)
import AppKit
import UserNotifications

enum EaseFocusSceneID {
    static let main = "main"
}

enum EaseFocusWindow {
    private static var primaryWindowNumber: Int?
    private static var isGuarding = false

    @MainActor
    static func handoffToRunningInstanceIfNeeded() {
        let identifier = Bundle.main.bundleIdentifier ?? "lil.pomodoro"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard let other = others.first else {
            return
        }
        other.activate(options: [.activateIgnoringOtherApps])
        exit(0)
    }

    @MainActor
    static func startGuarding() {
        guard !isGuarding else {
            return
        }
        isGuarding = true
        NSWindow.allowsAutomaticWindowTabbing = false
        rememberPrimaryIfNeeded()

        let names = [
            NSWindow.didBecomeKeyNotification,
            NSApplication.didBecomeActiveNotification,
        ]
        for name in names {
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    closeDuplicatesKeepingPrimary()
                }
            }
        }
    }

    @MainActor
    static func focusExisting() {
        NSApp.activate(ignoringOtherApps: true)
        closeDuplicatesKeepingPrimary()
    }

    @MainActor
    static func focusExistingAfterNotification() {
        focusExisting()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            closeDuplicatesKeepingPrimary()
            try? await Task.sleep(for: .milliseconds(200))
            closeDuplicatesKeepingPrimary()
            try? await Task.sleep(for: .milliseconds(500))
            closeDuplicatesKeepingPrimary()
        }
    }

    @MainActor
    private static func closeDuplicatesKeepingPrimary() {
        rememberPrimaryIfNeeded()
        let mains = NSApp.windows.filter(isMainDocumentWindow)
        guard let primary = mains.first(where: { $0.windowNumber == primaryWindowNumber })
            ?? mains.max(by: { subviewCount($0) < subviewCount($1) })
        else {
            return
        }
        primaryWindowNumber = primary.windowNumber
        if primary.isMiniaturized {
            primary.deminiaturize(nil)
        }
        primary.makeKeyAndOrderFront(nil)
        for window in mains where window.windowNumber != primary.windowNumber {
            window.close()
        }
    }

    @MainActor
    private static func rememberPrimaryIfNeeded() {
        if let primaryWindowNumber,
           NSApp.windows.contains(where: { $0.windowNumber == primaryWindowNumber }) {
            return
        }
        primaryWindowNumber = NSApp.windows
            .filter(isMainDocumentWindow)
            .max { subviewCount($0) < subviewCount($1) }?
            .windowNumber
    }

    private static func isMainDocumentWindow(_ window: NSWindow) -> Bool {
        guard window.level == .normal,
              window.canBecomeMain,
              !window.isSheet,
              window.styleMask.contains(.titled),
              window.styleMask.contains(.closable)
        else {
            return false
        }
        let title = window.title
        if title == "Timer" || title.contains("Welcome") {
            return false
        }
        let className = String(describing: type(of: window))
        if className.contains("NSStatusBar")
            || className.contains("NSMenu")
            || className.contains("NSPanel")
            || className.contains("Popover") {
            return false
        }
        return true
    }

    private static func subviewCount(_ window: NSWindow) -> Int {
        func count(_ view: NSView?) -> Int {
            guard let view else {
                return 0
            }
            return 1 + view.subviews.reduce(0) { $0 + count($1) }
        }
        return count(window.contentView)
    }
}

@MainActor
final class EaseFocusAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        EaseFocusWindow.handoffToRunningInstanceIfNeeded()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = EaseFocusNotificationDelegate.shared
        EaseFocusWindow.startGuarding()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        EaseFocusWindow.focusExisting()
        return false
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }
}
#else
enum EaseFocusSceneID {
    static let main = "main"
}
#endif
