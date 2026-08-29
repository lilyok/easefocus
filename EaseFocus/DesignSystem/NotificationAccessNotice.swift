import SwiftUI

struct NotificationAccessNotice: View {
    let access: NotificationAccess
    var settingsLinkIdentifier = "openNotificationSettings"

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            Text(NotificationAccessCopy.title(for: access))
                .font(FocusTypography.title)
                .foregroundStyle(access == .allowed ? Color.focusSuccess : Color.focusPrimary)
            Text(NotificationAccessCopy.message(for: access))
                .font(FocusTypography.body)
            if access != .allowed, let url = NotificationSettingsURL.make() {
                Link("Open Notifications Settings", destination: url)
                    .font(FocusTypography.body)
                    .accessibilityIdentifier(settingsLinkIdentifier)
            }
        }
        .frame(minHeight: FocusSpacing.minimumTapTarget, alignment: .leading)
        .accessibilityElement(children: access != .allowed ? .contain : .combine)
    }
}

#Preview("Turned off") {
    NotificationAccessNotice(access: .denied)
        .padding()
}
