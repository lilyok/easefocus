import Foundation

nonisolated struct FocusTimerSettings: Equatable, Codable, Sendable {
    var focusSeconds: Int = 25 * 60
    var shortBreakSeconds: Int = 5 * 60
    var longBreakSeconds: Int = 15 * 60
    var sessionsBeforeLongBreak: Int = 4
    var startBreaksAutomatically: Bool = false
}

nonisolated enum FocusTimerPhase: String, Equatable, Codable, Sendable {
    case idle
    case runningFocus
    case pausedFocus
    case runningBreak
    case pausedBreak
    case completed
}

nonisolated enum FocusTimerEvent: Equatable, Sendable {
    case didStartFocus(taskID: UUID?, plannedDurationSeconds: Int, startedAt: Date)
    case didCompleteFocus(elapsedSeconds: Int, endedAt: Date)
    case didCancelFocus(elapsedSeconds: Int, endedAt: Date)
    case didInterruptFocus(elapsedSeconds: Int, endedAt: Date)
    case didStartBreak(isLong: Bool, plannedDurationSeconds: Int)
    case didCompleteBreak
    case shouldScheduleNotification(Date)
    case shouldCancelNotification
}

nonisolated struct FocusTimerEngine: Equatable, Codable, Sendable {
    var settings: FocusTimerSettings
    var phase: FocusTimerPhase = .idle
    var taskID: UUID?
    var plannedDurationSeconds: Int = 0
    var remainingSeconds: Int = 0
    var periodEndsAt: Date?
    var accumulatedRunSeconds: Int = 0
    var runStartedAt: Date?
    var completedFocusCount: Int = 0
    var isLongBreak: Bool = false

    var isRunning: Bool {
        phase == .runningFocus || phase == .runningBreak
    }

    var isActive: Bool {
        phase != .idle
    }

    var isFocus: Bool {
        phase == .runningFocus || phase == .pausedFocus || phase == .completed
    }

    func remainingSeconds(at now: Date) -> Int {
        if let periodEndsAt, isRunning {
            return max(0, Int(periodEndsAt.timeIntervalSince(now).rounded(.down)))
        }
        return remainingSeconds
    }

    func elapsedSeconds(at now: Date) -> Int {
        var total = accumulatedRunSeconds
        if let runStartedAt {
            total += max(0, Int(now.timeIntervalSince(runStartedAt).rounded(.down)))
        }
        if plannedDurationSeconds > 0 {
            return min(total, plannedDurationSeconds)
        }
        return total
    }

    mutating func startFocus(taskID: UUID?, now: Date) -> [FocusTimerEvent] {
        guard phase == .idle || phase == .completed else {
            return []
        }

        self.taskID = taskID
        beginPeriod(duration: settings.focusSeconds, now: now)
        phase = .runningFocus
        isLongBreak = false
        return [
            .didStartFocus(taskID: taskID, plannedDurationSeconds: plannedDurationSeconds, startedAt: now),
            .shouldScheduleNotification(now.addingTimeInterval(TimeInterval(plannedDurationSeconds))),
        ]
    }

    mutating func pause(now: Date) -> [FocusTimerEvent] {
        guard isRunning else {
            return []
        }

        remainingSeconds = remainingSeconds(at: now)
        accumulatedRunSeconds = elapsedSeconds(at: now)
        runStartedAt = nil
        periodEndsAt = nil
        phase = phase == .runningFocus ? .pausedFocus : .pausedBreak
        return [.shouldCancelNotification]
    }

    mutating func resume(now: Date) -> [FocusTimerEvent] {
        guard phase == .pausedFocus || phase == .pausedBreak else {
            return []
        }

        runStartedAt = now
        periodEndsAt = now.addingTimeInterval(TimeInterval(remainingSeconds))
        phase = phase == .pausedFocus ? .runningFocus : .runningBreak
        return [.shouldScheduleNotification(periodEndsAt ?? now)]
    }

    mutating func cancel(now: Date) -> [FocusTimerEvent] {
        guard phase == .runningFocus || phase == .pausedFocus else {
            return resetToIdle()
        }

        let elapsed = elapsedSeconds(at: now)
        let events: [FocusTimerEvent] = [
            .didCancelFocus(elapsedSeconds: elapsed, endedAt: now),
            .shouldCancelNotification,
        ]
        _ = resetToIdle()
        return events
    }

    mutating func startBreak(now: Date) -> [FocusTimerEvent] {
        guard phase == .completed || phase == .idle else {
            return []
        }

        isLongBreak = settings.sessionsBeforeLongBreak > 0
            && completedFocusCount > 0
            && completedFocusCount.isMultiple(of: settings.sessionsBeforeLongBreak)
        let duration = isLongBreak ? settings.longBreakSeconds : settings.shortBreakSeconds
        taskID = nil
        beginPeriod(duration: duration, now: now)
        phase = .runningBreak
        return [
            .didStartBreak(isLong: isLongBreak, plannedDurationSeconds: duration),
            .shouldScheduleNotification(now.addingTimeInterval(TimeInterval(duration))),
        ]
    }

    mutating func skipBreak() -> [FocusTimerEvent] {
        guard phase == .completed else {
            return []
        }
        return resetToIdle()
    }

    mutating func tick(now: Date) -> [FocusTimerEvent] {
        guard isRunning else {
            return []
        }

        remainingSeconds = remainingSeconds(at: now)
        guard remainingSeconds == 0 else {
            return []
        }
        return completePeriod(now: now)
    }

    private mutating func completePeriod(now: Date) -> [FocusTimerEvent] {
        if phase == .runningFocus {
            let elapsed = elapsedSeconds(at: now)
            completedFocusCount += 1
            accumulatedRunSeconds = 0
            runStartedAt = nil
            periodEndsAt = nil
            remainingSeconds = 0
            phase = .completed
            var events: [FocusTimerEvent] = [
                .didCompleteFocus(elapsedSeconds: elapsed, endedAt: now),
                .shouldCancelNotification,
            ]
            if settings.startBreaksAutomatically {
                events.append(contentsOf: startBreak(now: now))
            }
            return events
        }

        phase = .idle
        accumulatedRunSeconds = 0
        runStartedAt = nil
        periodEndsAt = nil
        remainingSeconds = 0
        plannedDurationSeconds = 0
        taskID = nil
        isLongBreak = false
        return [
            .didCompleteBreak,
            .shouldCancelNotification,
        ]
    }

    private mutating func beginPeriod(duration: Int, now: Date) {
        plannedDurationSeconds = duration
        remainingSeconds = duration
        accumulatedRunSeconds = 0
        runStartedAt = now
        periodEndsAt = now.addingTimeInterval(TimeInterval(duration))
    }

    private mutating func resetToIdle() -> [FocusTimerEvent] {
        phase = .idle
        taskID = nil
        plannedDurationSeconds = 0
        remainingSeconds = 0
        periodEndsAt = nil
        accumulatedRunSeconds = 0
        runStartedAt = nil
        isLongBreak = false
        return [.shouldCancelNotification]
    }
}

nonisolated enum FocusDurationFormat {
    static func clock(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let remainder = clamped % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}
