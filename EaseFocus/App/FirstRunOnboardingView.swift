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
                    HStack {
                        Spacer(minLength: 0)
                        EaseFocusMark(size: 72)
                        Spacer(minLength: 0)
                    }
                    .listRowBackground(Color.clear)
                    Text(OnboardingCopy.introduction)
                        .font(FocusTypography.body)
                }

                Section {
                    NotificationAccessNotice(
                        access: timer.notificationAccess,
                        settingsLinkIdentifier: "onboardingOpenNotificationSettings"
                    )
                } header: {
                    Text(OnboardingCopy.notifications)
                }

                if availability.showsPlanSurvey {
                    Section {
                        AvailabilityNotice(availability: availability)
                    } header: {
                        Text(OnboardingCopy.appleIntelligence)
                    }
                }
            }
            .navigationTitle(OnboardingCopy.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(OnboardingCopy.continueAction, action: onContinue)
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
