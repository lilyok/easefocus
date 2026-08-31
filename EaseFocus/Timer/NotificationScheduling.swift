import Foundation
import UserNotifications
#if os(macOS)
import AppKit
#else
import AudioToolbox
#endif

protocol NotificationScheduling: Sendable {
    func currentAccess() async -> NotificationAccess
    func requestAuthorization() async -> Bool
    func scheduleTimerFinished(at date: Date) async
    func cancelTimerFinished()
    func announcePeriodFinished(isBreak: Bool)
}

struct UserNotificationScheduler: NotificationScheduling {
    static let timerFinishedIdentifier = "easefocus.timer.finished"
    static let timerFinishedNowIdentifier = "easefocus.timer.finished.now"

    init() {
        Self.installDelegateIfNeeded()
    }

    func requestAuthorization() async -> Bool {
        Self.installDelegateIfNeeded()
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func currentAccess() async -> NotificationAccess {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationAccess.from(authorizationStatus: settings.authorizationStatus)
    }

    func scheduleTimerFinished(at date: Date) async {
        cancelTimerFinished()
        let request = UNNotificationRequest(
            identifier: Self.timerFinishedIdentifier,
            content: makeContent(body: "Your timer has finished.", playsSound: true),
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, date.timeIntervalSinceNow),
                repeats: false
            )
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelTimerFinished() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.timerFinishedIdentifier])
    }

    func announcePeriodFinished(isBreak: Bool) {
        TimerAlertSound.play()
        Task {
            await deliverImmediateNotification(isBreak: isBreak)
        }
    }

    private func deliverImmediateNotification(isBreak: Bool) async {
        let request = UNNotificationRequest(
            identifier: Self.timerFinishedNowIdentifier,
            content: makeContent(
                body: isBreak ? "Break finished." : "Focus session complete.",
                playsSound: false
            ),
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func makeContent(body: String, playsSound: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "EaseFocus"
        content.body = body
        if playsSound {
            content.sound = .default
        }
        return content
    }

    private static func installDelegateIfNeeded() {
        UNUserNotificationCenter.current().delegate = EaseFocusNotificationDelegate.shared
    }
}

enum TimerAlertSound {
    static func play() {
        #if os(macOS)
        if let glass = NSSound(named: NSSound.Name("Glass")) {
            glass.play()
        } else {
            NSSound.beep()
        }
        NSApp.requestUserAttention(.informationalRequest)
        #else
        AudioServicesPlayAlertSound(SystemSoundID(1007))
        #endif
    }
}

final class EaseFocusNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = EaseFocusNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notification.request.identifier == UserNotificationScheduler.timerFinishedNowIdentifier {
            return [.banner, .list]
        }
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        #if os(macOS)
        await MainActor.run {
            EaseFocusWindow.focusExistingAfterNotification()
        }
        #endif
    }
}
