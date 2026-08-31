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
        #expect(NotificationAccessCopy.message(for: .allowed).contains("system settings"))
    }

    @Test
    func mapsSystemAuthorizationStatus() {
        #expect(
            NotificationAccess.from(authorizationStatus: .authorized) == .allowed
        )
        #expect(
            NotificationAccess.from(authorizationStatus: .provisional) == .allowed
        )
        #if os(iOS)
        #expect(
            NotificationAccess.from(authorizationStatus: .ephemeral) == .allowed
        )
        #endif
        #expect(
            NotificationAccess.from(authorizationStatus: .notDetermined) == .notDetermined
        )
        #expect(
            NotificationAccess.from(authorizationStatus: .denied) == .denied
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
