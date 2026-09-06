import SwiftUI

struct TimerView: View {
    @Environment(FocusTimerController.self) private var timer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: FocusSpacing.large) {
            Text(FocusDurationFormat.clock(remainingSeconds))
                .font(FocusTypography.timer)
                .monospacedDigit()
                .foregroundStyle(Color.focusPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity)
                .animation(
                    reduceMotion ? nil : .linear(duration: 0.2),
                    value: timer.engine.remainingSeconds
                )
                .accessibilityLabel(TimerAccessibilityCopy.remainingTime)
                .accessibilityValue(TimerAccessibilityPresentation.spokenRemaining(seconds: remainingSeconds))
                .accessibilityIdentifier(TimerAccessibilityIdentifier.remainingTime)
            Text(statusTitle)
                .font(FocusTypography.title)
                .foregroundStyle(Color.focusPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            controls
        }
        .padding(FocusSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.focusBackground)
        .navigationTitle("Timer")
    }

    @ViewBuilder
    private var controls: some View {
        if actions.isEmpty {
            Text(TimerAccessibilityCopy.startFromTask)
                .font(FocusTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ForEach(actions) { action in
                TimerPhaseControlButton(action: action, usesCompactTitle: false) {
                    timer.perform(action)
                }
            }
        }
    }

    private var actions: [CompactTimerAction] {
        TimerAccessibilityPresentation.actions(
            for: timer.engine.phase,
            reduceMotion: reduceMotion
        )
    }

    private var remainingSeconds: Int {
        timer.engine.remainingSeconds(at: .now)
    }

    private var statusTitle: String {
        TimerAccessibilityPresentation.statusTitle(
            phase: timer.engine.phase,
            isLongBreak: timer.engine.isLongBreak
        )
    }
}

#Preview {
    NavigationStack {
        TimerView()
    }
    .environment(FocusTimerController())
}
