import Foundation
import UserNotifications

protocol NotificationScheduling: Sendable {
    func requestAuthorization() async -> Bool
    func scheduleTimerFinished(at date: Date) async
    func cancelTimerFinished()
}

struct UserNotificationScheduler: NotificationScheduling {
    static let timerFinishedIdentifier = "easefocus.timer.finished"

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleTimerFinished(at date: Date) async {
        cancelTimerFinished()
        let content = UNMutableNotificationContent()
        content.title = "EaseFocus"
        content.body = "Your timer has finished."
        content.sound = .default

        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.timerFinishedIdentifier,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelTimerFinished() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.timerFinishedIdentifier])
    }
}
