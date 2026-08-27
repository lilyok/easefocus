import SwiftUI

struct TimerView: View {
    @Environment(FocusTimerController.self) private var timer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: FocusSpacing.large) {
            Text(FocusDurationFormat.clock(timer.engine.remainingSeconds(at: .now)))
                .font(FocusTypography.timer)
                .monospacedDigit()
                .animation(reduceMotion ? nil : .linear(duration: 0.2), value: timer.engine.remainingSeconds)
            Text(statusTitle)
                .font(FocusTypography.title)
                .foregroundStyle(Color.focusPrimary)
            controls
        }
        .padding(FocusSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.focusBackground)
        .navigationTitle("Timer")
    }

    @ViewBuilder
    private var controls: some View {
        switch timer.engine.phase {
        case .idle:
            Text("Start a focus session from a task.")
                .font(FocusTypography.body)
                .foregroundStyle(.secondary)
        case .runningFocus, .runningBreak:
            Button("Pause") { timer.pause() }
                .frame(minHeight: FocusSpacing.minimumTapTarget)
            Button("Cancel", role: .destructive) { timer.cancel() }
        case .pausedFocus, .pausedBreak:
            Button("Resume") { timer.resume() }
                .frame(minHeight: FocusSpacing.minimumTapTarget)
            Button("Cancel", role: .destructive) { timer.cancel() }
        case .completed:
            Button("Start break") { timer.startBreak() }
                .frame(minHeight: FocusSpacing.minimumTapTarget)
            Button("Skip break") { timer.skipBreak() }
        }
    }

    private var statusTitle: String {
        switch timer.engine.phase {
        case .idle:
            return "Idle"
        case .runningFocus:
            return "Focus"
        case .pausedFocus:
            return "Paused"
        case .runningBreak:
            return timer.engine.isLongBreak ? "Long break" : "Break"
        case .pausedBreak:
            return "Break paused"
        case .completed:
            return "Session complete"
        }
    }
}

#Preview {
    NavigationStack {
        TimerView()
    }
    .environment(FocusTimerController())
}
