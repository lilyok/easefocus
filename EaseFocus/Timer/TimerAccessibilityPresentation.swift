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

    static func hours(_ count: Int) -> LocalizedCopy {
        LocalizedCopy(format: "\(count) hours", english: "\(count) hours")
    }

    static func minutes(_ count: Int) -> LocalizedCopy {
        LocalizedCopy(format: "\(count) minutes", english: "\(count) minutes")
    }

    static func seconds(_ count: Int) -> LocalizedCopy {
        LocalizedCopy(format: "\(count) seconds", english: "\(count) seconds")
    }

    static func remaining(_ duration: String) -> LocalizedCopy {
        LocalizedCopy(format: "\(duration) remaining", english: "\(duration) remaining")
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
        var parts: [String] = []
        if hours > 0 {
            parts.append(TimerAccessibilityCopy.hours(hours).localized(locale))
        }
        if minutes > 0 {
            parts.append(TimerAccessibilityCopy.minutes(minutes).localized(locale))
        }
        if remainder > 0 || parts.isEmpty {
            parts.append(TimerAccessibilityCopy.seconds(remainder).localized(locale))
        }
        return TimerAccessibilityCopy.remaining(parts.joined(separator: " ")).localized(locale)
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
