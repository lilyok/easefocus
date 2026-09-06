import Foundation

nonisolated enum CompactTimerAction: String, Equatable, Sendable, Identifiable, CaseIterable {
    case pause
    case resume
    case cancel
    case startBreak
    case skipBreak

    var id: String { rawValue }

    var identifier: String {
        switch self {
        case .pause:
            TimerAccessibilityIdentifier.pause
        case .resume:
            TimerAccessibilityIdentifier.resume
        case .cancel:
            TimerAccessibilityIdentifier.cancel
        case .startBreak:
            TimerAccessibilityIdentifier.startBreak
        case .skipBreak:
            TimerAccessibilityIdentifier.skipBreak
        }
    }

    var compactTitle: String {
        switch self {
        case .pause:
            "Pause"
        case .resume:
            "Resume"
        case .cancel:
            "Cancel"
        case .startBreak:
            "Break"
        case .skipBreak:
            "Skip"
        }
    }

    var title: String {
        switch self {
        case .pause:
            "Pause"
        case .resume:
            "Resume"
        case .cancel:
            "Cancel"
        case .startBreak:
            "Start break"
        case .skipBreak:
            "Skip break"
        }
    }

    var accessibilityLabel: String { title }
}

nonisolated enum TimerAccessibilityIdentifier {
    static let compactTimer = "compactTimer"
    static let openTimer = "openTimer"
    static let remainingTime = "remainingTime"
    static let timerRemainingTime = "timerRemainingTime"
    static let pause = "pause"
    static let resume = "resume"
    static let cancel = "cancel"
    static let startBreak = "startBreak"
    static let skipBreak = "skipBreak"
}

nonisolated enum TimerAccessibilityCopy {
    static let remainingTime = "Remaining time"
    static let openTimerHint = "Opens the full timer"
    static let idle = "Idle"
    static let focus = "Focus"
    static let focusPaused = "Focus paused"
    static let breakStatus = "Break"
    static let longBreak = "Long break"
    static let breakPaused = "Break paused"
    static let focusComplete = "Focus complete"
    static let startFromTask = "Start a focus session from a task."
    static let startFocus = "Start focus"
}

nonisolated enum TimerAccessibilityPresentation {
    static func statusTitle(phase: FocusTimerPhase, isLongBreak: Bool) -> String {
        switch phase {
        case .idle:
            TimerAccessibilityCopy.idle
        case .runningFocus:
            TimerAccessibilityCopy.focus
        case .pausedFocus:
            TimerAccessibilityCopy.focusPaused
        case .runningBreak:
            isLongBreak ? TimerAccessibilityCopy.longBreak : TimerAccessibilityCopy.breakStatus
        case .pausedBreak:
            TimerAccessibilityCopy.breakPaused
        case .completed:
            TimerAccessibilityCopy.focusComplete
        }
    }

    static func spokenRemaining(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let remainder = clamped % 60
        var parts: [String] = []
        if hours > 0 {
            parts.append(unitPhrase(hours, singular: "hour", plural: "hours"))
        }
        if minutes > 0 {
            parts.append(unitPhrase(minutes, singular: "minute", plural: "minutes"))
        }
        if remainder > 0 || parts.isEmpty {
            parts.append(unitPhrase(remainder, singular: "second", plural: "seconds"))
        }
        return parts.joined(separator: " ") + " remaining"
    }

    static func actions(for phase: FocusTimerPhase, reduceMotion: Bool = false) -> [CompactTimerAction] {
        _ = reduceMotion
        switch phase {
        case .idle:
            return []
        case .runningFocus, .runningBreak:
            return [.pause, .cancel]
        case .pausedFocus, .pausedBreak:
            return [.resume, .cancel]
        case .completed:
            return [.startBreak, .skipBreak]
        }
    }

    private static func unitPhrase(_ value: Int, singular: String, plural: String) -> String {
        value == 1 ? "1 \(singular)" : "\(value) \(plural)"
    }
}
