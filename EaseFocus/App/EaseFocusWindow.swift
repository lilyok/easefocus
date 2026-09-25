#if os(macOS)
import AppKit
import UserNotifications

enum EaseFocusSceneID {
    static let main = "main"
}

enum EaseFocusWindow {
    private static var primaryWindowNumber: Int?
    private static var isGuarding = false
    /// While share sheets / Freeform / Journal UI is up, do not close or steal key windows.
    private static var isGuardSuspended = false

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
    static func suspendDuplicateGuarding() {
        isGuardSuspended = true
    }

    @MainActor
    static func resumeDuplicateGuarding() {
        isGuardSuspended = false
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
        guard !isGuardSuspended else {
            return
        }
        rememberPrimaryIfNeeded()
        let mains = NSApp.windows.filter(isMainDocumentWindow)
        guard let primary = mains.first(where: { $0.windowNumber == primaryWindowNumber })
            ?? mains.max(by: { subviewCount($0) < subviewCount($1) })
        else {
            return
        }
        primaryWindowNumber = primary.windowNumber

        // Only close true duplicates of our primary window — never share-extension
        // panels (Freeform board name, Journal, etc.).
        for window in mains where window.windowNumber != primary.windowNumber {
            let sameTitle = window.title == primary.title
                || (window.title.isEmpty && primary.title.isEmpty)
            guard sameTitle else {
                continue
            }
            window.close()
        }

        // Share sheets become key so the user can type. Do not reclaim focus.
        guard let key = NSApp.keyWindow else {
            presentPrimary(primary)
            return
        }
        if key.windowNumber == primary.windowNumber {
            return
        }
        if isMainDocumentWindow(key), key.title == primary.title || key.title.isEmpty {
            presentPrimary(primary)
        }
    }

    @MainActor
    private static func presentPrimary(_ primary: NSWindow) {
        if primary.isMiniaturized {
            primary.deminiaturize(nil)
        }
        primary.makeKeyAndOrderFront(nil)
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
        if title == AppCopy.timer.localized()
            || title == OnboardingCopy.navigationTitle.localized() {
            return false
        }
        let className = String(describing: type(of: window))
        if className.contains("NSStatusBar")
            || className.contains("NSMenu")
            || className.contains("NSPanel")
            || className.contains("Popover")
            || className.contains("Share")
            || className.contains("Extension")
            || className.contains("Remote") {
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

enum EaseFocusDockIcon {
    @MainActor
    static func apply() {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url)
        else {
            return
        }
        NSApp.applicationIconImage = squircleMasked(image)
    }

    private static func squircleMasked(_ image: NSImage) -> NSImage {
        let size = image.size.width > 0 ? image.size : NSSize(width: 1024, height: 1024)
        return NSImage(size: size, flipped: false) { rect in
            let radius = min(rect.width, rect.height) * 0.2237
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
            image.draw(
                in: rect,
                from: NSRect(origin: .zero, size: image.size),
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
    }
}

@MainActor
final class EaseFocusAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        EaseFocusDockIcon.apply()
        EaseFocusWindow.handoffToRunningInstanceIfNeeded()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        EaseFocusDockIcon.apply()
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
