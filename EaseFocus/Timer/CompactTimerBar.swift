import SwiftUI

struct CompactTimerBar: View {
    @Environment(FocusTimerController.self) private var timer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onOpenTimer: () -> Void

    var body: some View {
        HStack(spacing: FocusSpacing.medium) {
            Button(action: onOpenTimer) {
                Text(statusTitle)
                    .font(FocusTypography.footnote)
            }
            .accessibilityIdentifier("openTimer")
            Spacer()
            Button(action: onOpenTimer) {
                Text(FocusDurationFormat.clock(timer.engine.remainingSeconds(at: .now)))
                    .font(FocusTypography.timer)
                    .monospacedDigit()
                    .animation(reduceMotion ? nil : .linear(duration: 0.25), value: timer.engine.remainingSeconds)
            }
            .buttonStyle(.plain)
            controls
        }
        .padding(.horizontal, FocusSpacing.medium)
        .padding(.vertical, FocusSpacing.small)
        .frame(minHeight: FocusSpacing.minimumTapTarget)
        .background(Color.focusSurface)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("compactTimer")
    }

    @ViewBuilder
    private var controls: some View {
        switch timer.engine.phase {
        case .runningFocus, .runningBreak:
            Button("Pause") { timer.pause() }
            Button("Cancel", role: .destructive) { timer.cancel() }
        case .pausedFocus, .pausedBreak:
            Button("Resume") { timer.resume() }
            Button("Cancel", role: .destructive) { timer.cancel() }
        case .completed:
            Button("Break") { timer.startBreak() }
            Button("Skip") { timer.skipBreak() }
        case .idle:
            EmptyView()
        }
    }

    private var statusTitle: String {
        switch timer.engine.phase {
        case .idle:
            return "Idle"
        case .runningFocus:
            return "Focus"
        case .pausedFocus:
            return "Focus paused"
        case .runningBreak:
            return timer.engine.isLongBreak ? "Long break" : "Break"
        case .pausedBreak:
            return "Break paused"
        case .completed:
            return "Focus complete"
        }
    }
}
