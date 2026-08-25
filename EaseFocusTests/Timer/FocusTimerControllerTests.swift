import Foundation
import Testing
@testable import EaseFocus

private struct SilentNotifications: NotificationScheduling {
    func requestAuthorization() async -> Bool { false }
    func scheduleTimerFinished(at date: Date) async {}
    func cancelTimerFinished() {}
}

struct FocusTimerControllerTests {
    @Test
    @MainActor
    func restoresSavedSettingsOnRelaunch() {
        let suiteName = "easefocus.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = FocusTimerController(
            settings: FocusTimerSettings(focusSeconds: 25 * 60),
            notifications: SilentNotifications(),
            defaults: defaults
        )
        first.settings.focusSeconds = 15 * 60
        first.settings.shortBreakSeconds = 3 * 60
        first.settings.startBreaksAutomatically = true

        let relaunched = FocusTimerController(
            settings: FocusTimerSettings(focusSeconds: 99 * 60),
            notifications: SilentNotifications(),
            defaults: defaults
        )

        #expect(relaunched.settings.focusSeconds == 15 * 60)
        #expect(relaunched.settings.shortBreakSeconds == 3 * 60)
        #expect(relaunched.settings.startBreaksAutomatically)
    }
}
