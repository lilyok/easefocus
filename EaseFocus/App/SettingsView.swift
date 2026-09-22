import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.foundationModelClient) private var foundationModelClient
    @Environment(\.locale) private var locale
    @Environment(FocusTimerController.self) private var timer

    private var availability: FoundationModelAvailability {
        foundationModelClient.currentAvailability(locale: locale)
    }

    var body: some View {
        NavigationStack {
            FocusScreenStack {
                FocusSectionHeader(title: SettingsCopy.timer)
                VStack(alignment: .leading, spacing: FocusSpacing.small) {
                    durationStepper(seconds: focusSecondsBinding, label: SettingsCopy.focusMinutes)
                    durationStepper(seconds: shortBreakBinding, label: SettingsCopy.shortBreak)
                    durationStepper(seconds: longBreakBinding, label: SettingsCopy.longBreak)
                    integerStepper(
                        value: sessionsBeforeLongBreakBinding,
                        range: 2...8,
                        label: SettingsCopy.sessionsBeforeLongBreak
                    )
                    Toggle(SettingsCopy.startBreaksAutomatically, isOn: automaticBreakBinding)
                    Toggle(SettingsCopy.playTimerSounds, isOn: playTimerSoundsBinding)
                }
                .focusCard()

                FocusSectionHeader(title: SettingsCopy.notifications)
                NotificationAccessNotice(access: timer.notificationAccess)
                    .focusCard()

                FocusSectionHeader(title: SettingsCopy.appleIntelligence)
                VStack(alignment: .leading, spacing: FocusSpacing.small) {
                    AvailabilityNotice(availability: availability)
                    Text(SettingsCopy.generatedPlansHint)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
                .focusCard()

                FocusSectionHeader(title: SettingsCopy.privacy)
                Text(SettingsCopy.privacyOverview)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(Color.focusPrimary)
                    .focusCard()
            }
            .navigationTitle(SettingsCopy.navigationTitle)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FocusCapsuleButton(
                    title: AppCopy.close,
                    identifier: "closeSettings",
                    action: { dismiss() }
                )
                .padding(.horizontal, FocusSpacing.medium)
                .padding(.vertical, FocusSpacing.small)
                .background(Color.focusBackground)
            }
            .task {
                await timer.refreshNotificationAccess()
            }
        }
        .focusScreen()
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
        seconds: Binding<Int>,
        label: LocalizedCopy
    ) -> some View {
        integerStepper(
            value: Binding(
                get: { seconds.wrappedValue / 60 },
                set: { seconds.wrappedValue = max(60, $0 * 60) }
            ),
            range: 1...60,
            label: label
        )
    }

    private func integerStepper(
        value: Binding<Int>,
        range: ClosedRange<Int>,
        label: LocalizedCopy
    ) -> some View {
        HStack(alignment: .center, spacing: FocusSpacing.medium) {
            Text(label)
                .font(FocusTypography.body)
                .foregroundStyle(Color.focusPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(value.wrappedValue)")
                .font(FocusTypography.body.monospacedDigit())
                .foregroundStyle(Color.focusPrimary)
                .frame(width: 36, alignment: .trailing)
            Stepper(value: value, in: range) {
                Text(label)
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel(label)
            .accessibilityValue("\(value.wrappedValue)")
        }
        .frame(minHeight: FocusSpacing.minimumTapTarget)
    }
}

#Preview {
    SettingsView()
        .environment(FocusTimerController())
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
}
