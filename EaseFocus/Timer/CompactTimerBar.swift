import SwiftUI

struct CompactTimerBar: View {
    @Environment(FocusTimerController.self) private var timer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onOpenTimer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            HStack(alignment: .center, spacing: FocusSpacing.small) {
                openTimerButton
                Spacer(minLength: 0)
                remainingTimeControl
            }
            if !actions.isEmpty {
                HStack(spacing: FocusSpacing.small) {
                    ForEach(actions) { action in
                        TimerPhaseControlButton(action: action, usesCompactTitle: true) {
                            timer.perform(action)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, FocusSpacing.medium)
        .padding(.vertical, FocusSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.focusSurface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TimerAccessibilityIdentifier.compactTimer)
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

    private var openTimerButton: some View {
        Button(action: onOpenTimer) {
            Text(statusTitle)
                .font(FocusTypography.footnote)
                .foregroundStyle(Color.focusPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    minWidth: FocusSpacing.minimumTapTarget,
                    minHeight: FocusSpacing.minimumTapTarget,
                    alignment: .leading
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(statusTitle)
        .accessibilityHint(TimerAccessibilityCopy.openTimerHint)
        .accessibilityIdentifier(TimerAccessibilityIdentifier.openTimer)
    }

    private var remainingTimeControl: some View {
        Button(action: onOpenTimer) {
            Text(FocusDurationFormat.clock(remainingSeconds))
                .font(FocusTypography.compactTimer)
                .monospacedDigit()
                .foregroundStyle(Color.focusPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(
                    minWidth: FocusSpacing.minimumTapTarget,
                    minHeight: FocusSpacing.minimumTapTarget
                )
                .animation(
                    reduceMotion ? nil : .linear(duration: 0.25),
                    value: timer.engine.remainingSeconds
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TimerAccessibilityCopy.remainingTime)
        .accessibilityValue(TimerAccessibilityPresentation.spokenRemaining(seconds: remainingSeconds))
        .accessibilityHint(TimerAccessibilityCopy.openTimerHint)
        .accessibilityIdentifier(TimerAccessibilityIdentifier.remainingTime)
    }

    private var statusTitle: String {
        TimerAccessibilityPresentation.statusTitle(
            phase: timer.engine.phase,
            isLongBreak: timer.engine.isLongBreak
        )
    }
}
