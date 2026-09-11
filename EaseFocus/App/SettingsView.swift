import SwiftUI

struct SettingsView: View {
    @Environment(\.foundationModelClient) private var foundationModelClient
    @Environment(\.locale) private var locale
    @Environment(FocusTimerController.self) private var timer

    private var availability: FoundationModelAvailability {
        foundationModelClient.currentAvailability(locale: locale)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    durationStepper(minutes: focusSecondsBinding, label: SettingsCopy.focusMinutes)
                    durationStepper(minutes: shortBreakBinding, label: SettingsCopy.shortBreak)
                    durationStepper(minutes: longBreakBinding, label: SettingsCopy.longBreak)
                    Stepper(value: sessionsBeforeLongBreakBinding, in: 2...8) {
                        Text(SettingsCopy.sessionsBeforeLongBreak(timer.settings.sessionsBeforeLongBreak))
                    }
                    Toggle(SettingsCopy.startBreaksAutomatically, isOn: automaticBreakBinding)
                    Toggle(SettingsCopy.playTimerSounds, isOn: playTimerSoundsBinding)
                } header: {
                    Text(SettingsCopy.timer)
                }

                Section {
                    NotificationAccessNotice(access: timer.notificationAccess)
                } header: {
                    Text(SettingsCopy.notifications)
                }

                Section {
                    AvailabilityNotice(availability: availability)
                    Text(SettingsCopy.generatedPlansHint)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(SettingsCopy.appleIntelligence)
                }

                Section {
                    Text(SettingsCopy.privacyOverview)
                        .font(FocusTypography.footnote)
                    Text(ExternalSearchPrivacyCopy.body)
                        .font(FocusTypography.footnote)
                } header: {
                    Text(SettingsCopy.privacy)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.focusBackground)
            .navigationTitle(SettingsCopy.navigationTitle)
            .task {
                await timer.refreshNotificationAccess()
            }
        }
    }

    private var focusSecondsBinding: Binding<Int> {
        Binding(
            get: { timer.settings.focusSeconds },
            set: { timer.settings.focusSeconds = $0 }
        )
    }

    private var shortBreakBinding: Binding<Int> {
        Binding(
            get: { timer.settings.shortBreakSeconds },
            set: { timer.settings.shortBreakSeconds = $0 }
        )
    }

    private var longBreakBinding: Binding<Int> {
        Binding(
            get: { timer.settings.longBreakSeconds },
            set: { timer.settings.longBreakSeconds = $0 }
        )
    }

    private var automaticBreakBinding: Binding<Bool> {
        Binding(
            get: { timer.settings.startBreaksAutomatically },
            set: { timer.settings.startBreaksAutomatically = $0 }
        )
    }

    private var sessionsBeforeLongBreakBinding: Binding<Int> {
        Binding(
            get: { timer.settings.sessionsBeforeLongBreak },
            set: { timer.settings.sessionsBeforeLongBreak = min(8, max(2, $0)) }
        )
    }

    private var playTimerSoundsBinding: Binding<Bool> {
        Binding(
            get: { timer.settings.playsCompletionSound },
            set: { timer.settings.playsCompletionSound = $0 }
        )
    }

    private func durationStepper(
        minutes seconds: Binding<Int>,
        label: (Int) -> LocalizedCopy
    ) -> some View {
        Stepper(value: Binding(
            get: { seconds.wrappedValue / 60 },
            set: { seconds.wrappedValue = max(60, $0 * 60) }
        ), in: 1...60) {
            Text(label(seconds.wrappedValue / 60))
        }
    }
}

#Preview {
    SettingsView()
        .environment(FocusTimerController())
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
}
