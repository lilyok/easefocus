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

    var compactTitle: LocalizedCopy {
        switch self {
        case .pause:
            LocalizedCopy("Pause")
        case .resume:
            LocalizedCopy("Resume")
        case .cancel:
            AppCopy.cancel
        case .startBreak:
            LocalizedCopy("Break")
        case .skipBreak:
            LocalizedCopy("Skip")
        }
    }

    var title: LocalizedCopy {
        switch self {
        case .pause:
            LocalizedCopy("Pause")
        case .resume:
            LocalizedCopy("Resume")
        case .cancel:
            AppCopy.cancel
        case .startBreak:
            LocalizedCopy("Start break")
        case .skipBreak:
            LocalizedCopy("Skip break")
        }
    }

    var accessibilityLabel: LocalizedCopy { title }
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
    static let remainingTime = LocalizedCopy("Remaining time")
    static let openTimerHint = LocalizedCopy("Opens the full timer")
    static let idle = LocalizedCopy("Idle")
    static let focus = LocalizedCopy("Focus")
    static let focusPaused = LocalizedCopy("Focus paused")
    static let breakStatus = LocalizedCopy("Break")
    static let longBreak = LocalizedCopy("Long break")
    static let breakPaused = LocalizedCopy("Break paused")
    static let focusComplete = LocalizedCopy("Focus complete")
    static let startFromTask = LocalizedCopy("Start a focus session from a task.")
    static let startFocus = AppCopy.startFocus

    static let zeroSecondsRemaining = LocalizedCopy("0 seconds remaining")

    static func remaining(hours: Int, minutes: Int, seconds: Int) -> LocalizedCopy {
        let remainingCount = remainingAdjectiveCount(hours: hours, minutes: minutes, seconds: seconds)
        return LocalizedCopy(
            format: "\(hours) hours \(minutes) minutes \(seconds) seconds \(remainingCount) remaining",
            english: englishSpokenRemaining(hours: hours, minutes: minutes, seconds: seconds)
        )
    }

    private static func remainingAdjectiveCount(hours: Int, minutes: Int, seconds: Int) -> Int {
        let visibleUnits = [hours, minutes, seconds].filter { $0 > 0 }
        if visibleUnits == [1] {
            return 1
        }
        return 2
    }

    private static func englishSpokenRemaining(hours: Int, minutes: Int, seconds: Int) -> String {
        var parts: [String] = []
        if hours > 0 {
            parts.append(hours == 1 ? "\(hours) hour" : "\(hours) hours")
        }
        if minutes > 0 {
            parts.append(minutes == 1 ? "\(minutes) minute" : "\(minutes) minutes")
        }
        if seconds > 0 || parts.isEmpty {
            parts.append(seconds == 1 ? "\(seconds) second" : "\(seconds) seconds")
        }
        return "\(parts.joined(separator: " ")) remaining"
    }
}

nonisolated enum TimerAccessibilityPresentation {
    static func statusTitle(phase: FocusTimerPhase, isLongBreak: Bool) -> LocalizedCopy {
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

    static func spokenRemaining(
        seconds: Int,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let remainder = clamped % 60
        if hours == 0, minutes == 0, remainder == 0 {
            return TimerAccessibilityCopy.zeroSecondsRemaining.localized(locale)
        }
        return collapsedSpaces(
            TimerAccessibilityCopy.remaining(
                hours: hours,
                minutes: minutes,
                seconds: remainder
            ).localized(locale)
        )
    }

    private static func collapsedSpaces(_ string: String) -> String {
        string
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
}
