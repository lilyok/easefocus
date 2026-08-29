import SwiftUI

struct FirstRunOnboardingView: View {
    @Environment(\.locale) private var locale
    @Environment(\.foundationModelClient) private var foundationModelClient
    @Environment(FocusTimerController.self) private var timer

    var onContinue: () -> Void

    private var availability: FoundationModelAvailability {
        foundationModelClient.currentAvailability(locale: locale)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("EaseFocus turns a goal into timed focus sessions. Allow these so the timer and generated plans can work fully.")
                        .font(FocusTypography.body)
                }

                Section("Notifications") {
                    NotificationAccessNotice(
                        access: timer.notificationAccess,
                        settingsLinkIdentifier: "onboardingOpenNotificationSettings"
                    )
                }

                if availability.showsPlanSurvey {
                    Section("Apple Intelligence") {
                        AvailabilityNotice(availability: availability)
                    }
                }
            }
            .navigationTitle("Welcome to EaseFocus")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue", action: onContinue)
                        .accessibilityIdentifier("onboardingContinue")
                }
            }
            .task {
                await timer.refreshNotificationAccess()
                if timer.notificationAccess == .notDetermined {
                    _ = await timer.requestNotificationPermission()
                    await timer.refreshNotificationAccess()
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 520)
        #endif
    }
}

#Preview {
    FirstRunOnboardingView(onContinue: {})
        .environment(FocusTimerController())
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
}
