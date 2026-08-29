import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#endif

nonisolated enum NotificationAccess: Equatable, Sendable {
    case notDetermined
    case denied
    case allowed

    static func from(authorizationStatus: UNAuthorizationStatus) -> NotificationAccess {
        switch authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
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
            return "EaseFocus notifications are allowed. Alert style and sound follow your system settings."
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
