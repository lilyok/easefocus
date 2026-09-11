import SwiftUI

struct TimerView: View {
    @Environment(FocusTimerController.self) private var timer
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: FocusSpacing.large) {
            remainingTimeDisplay
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
        .navigationTitle(AppCopy.timer)
    }

    private var remainingTimeDisplay: some View {
        ZStack {
            FocusTimerProgressRing(progress: progressFraction)
                .animation(
                    reduceMotion ? nil : .linear(duration: 0.2),
                    value: progressFraction
                )
            // Propose the ring’s inner width so ViewThatFits steps down before digits
            // spill past the arc (especially at larger Dynamic Type).
            ViewThatFits(in: .horizontal) {
                remainingClockText(font: FocusTypography.timer)
                remainingClockText(font: FocusTypography.timerFitted)
                remainingClockText(font: FocusTypography.compactTimer)
            }
            .padding(FocusSpacing.large)
        }
        .frame(width: ringSize, height: ringSize)
        .frame(maxWidth: .infinity)
        .animation(
            reduceMotion ? nil : .linear(duration: 0.2),
            value: timer.engine.remainingSeconds
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TimerAccessibilityCopy.remainingTime)
        .accessibilityValue(TimerAccessibilityPresentation.spokenRemaining(seconds: remainingSeconds, locale: locale))
        .accessibilityIdentifier(TimerAccessibilityIdentifier.timerRemainingTime)
    }

    private func remainingClockText(font: Font) -> some View {
        Text(FocusDurationFormat.clock(remainingSeconds))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(Color.focusPrimary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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

    private var progressFraction: CGFloat {
        let planned = timer.engine.plannedDurationSeconds
        guard planned > 0 else { return 0 }
        let elapsed = max(0, planned - remainingSeconds)
        return CGFloat(elapsed) / CGFloat(planned)
    }

    private var ringSize: CGFloat {
        220
    }

    private var statusTitle: LocalizedCopy {
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
