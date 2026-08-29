import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#endif

nonisolated enum NotificationAccess: Equatable, Sendable {
    case notDetermined
    case denied
    case allowed

    /// macOS can leave `authorizationStatus` as authorized after the user turns the app
    /// off in Notifications settings. Delivery flags are the source of truth in that case.
    static func from(
        authorizationStatus: UNAuthorizationStatus,
        alertSetting: UNNotificationSetting,
        soundSetting: UNNotificationSetting,
        notificationCenterSetting: UNNotificationSetting
    ) -> NotificationAccess {
        switch authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            let delivery = [alertSetting, soundSetting, notificationCenterSetting]
            let supported = delivery.filter { $0 != .notSupported }
            if !supported.isEmpty, supported.allSatisfy({ $0 == .disabled }) {
                return .denied
            }
            return .allowed
        @unknown default:
            return .denied
        }
    }
}

nonisolated enum NotificationAccessCopy {
    static func title(for access: NotificationAccess) -> String {
        switch access {
        case .notDetermined:
            return "Notifications are off until you allow them"
        case .denied:
            return "Notifications are turned off"
        case .allowed:
            return "Notifications are on"
        }
    }

    static func message(for access: NotificationAccess) -> String {
        switch access {
        case .notDetermined, .denied:
            #if os(macOS)
            return "Turn on EaseFocus notifications in System Settings to get an alert when a timer ends."
            #else
            return "Turn on EaseFocus notifications in Settings to get an alert when a timer ends."
            #endif
        case .allowed:
            return "EaseFocus will banner and sound when a focus session or break ends."
        }
    }
}

nonisolated enum NotificationSettingsURL {
    static func make() -> URL? {
        #if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=lil.pomodoro")
        #else
        URL(string: UIApplication.openNotificationSettingsURLString)
        #endif
    }
}
