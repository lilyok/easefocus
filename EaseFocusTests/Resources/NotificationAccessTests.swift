import Foundation
import Testing
import UserNotifications
@testable import EaseFocus

struct NotificationAccessTests {
    @Test
    func explainsHowToAllowNotifications() {
        #expect(NotificationAccessCopy.title(for: .notDetermined).contains("off until you allow"))
        #expect(NotificationAccessCopy.message(for: .notDetermined).contains("Settings"))
        #expect(NotificationAccessCopy.title(for: .denied).contains("turned off"))
        #expect(NotificationAccessCopy.message(for: .allowed).contains("banner"))
    }

    @Test
    func treatsDisabledDeliveryAsOffEvenIfAuthorized() {
        #expect(
            NotificationAccess.from(
                authorizationStatus: .authorized,
                alertSetting: .disabled,
                soundSetting: .disabled,
                notificationCenterSetting: .disabled
            ) == .denied
        )
        #expect(
            NotificationAccess.from(
                authorizationStatus: .authorized,
                alertSetting: .enabled,
                soundSetting: .disabled,
                notificationCenterSetting: .disabled
            ) == .allowed
        )
        #expect(
            NotificationAccess.from(
                authorizationStatus: .authorized,
                alertSetting: .notSupported,
                soundSetting: .notSupported,
                notificationCenterSetting: .notSupported
            ) == .allowed
        )
        #expect(
            NotificationAccess.from(
                authorizationStatus: .notDetermined,
                alertSetting: .disabled,
                soundSetting: .disabled,
                notificationCenterSetting: .disabled
            ) == .notDetermined
        )
        #expect(
            NotificationAccess.from(
                authorizationStatus: .denied,
                alertSetting: .enabled,
                soundSetting: .enabled,
                notificationCenterSetting: .enabled
            ) == .denied
        )
    }

    @Test
    func opensNotificationSettings() throws {
        let url = try #require(NotificationSettingsURL.make())
        #if os(macOS)
        #expect(url.scheme == "x-apple.systempreferences")
        #expect(url.absoluteString.contains("Notifications"))
        #else
        #expect(url.absoluteString.contains("notification") || url.scheme == "app-settings")
        #endif
    }
}
