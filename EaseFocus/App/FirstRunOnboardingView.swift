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
            FocusScreenStack {
                VStack(spacing: FocusSpacing.medium) {
                    EaseFocusMark(size: 72)
                    Text(OnboardingCopy.introduction)
                        .font(FocusTypography.body)
                        .foregroundStyle(Color.focusPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .focusCard()

                FocusSectionHeader(title: OnboardingCopy.notifications)
                NotificationAccessNotice(
                    access: timer.notificationAccess,
                    settingsLinkIdentifier: "onboardingOpenNotificationSettings"
                )
                .focusCard()

                if availability.showsPlanSurvey {
                    FocusSectionHeader(title: OnboardingCopy.appleIntelligence)
                    AvailabilityNotice(availability: availability)
                        .focusCard()
                }

                FocusCapsuleButton(
                    title: OnboardingCopy.continueAction,
                    identifier: "onboardingContinue",
                    action: onContinue
                )
            }
            .navigationTitle(OnboardingCopy.navigationTitle)
            .task {
                await timer.refreshNotificationAccess()
                if timer.notificationAccess == .notDetermined {
                    _ = await timer.requestNotificationPermission()
                    await timer.refreshNotificationAccess()
                }
            }
        }
        .focusScreen()
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
