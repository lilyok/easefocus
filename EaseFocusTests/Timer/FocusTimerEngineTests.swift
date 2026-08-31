import Foundation
import Testing
@testable import EaseFocus

struct FocusTimerEngineTests {
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func startsAFocusPeriodAndCompletesFromTheEndDate() {
        var engine = FocusTimerEngine(settings: FocusTimerSettings(focusSeconds: 60))

        let startEvents = engine.startFocus(taskID: nil, now: start)
        #expect(engine.phase == .runningFocus)
        #expect(startEvents.contains(.didStartFocus(taskID: nil, plannedDurationSeconds: 60, startedAt: start)))

        let mid = start.addingTimeInterval(20)
        #expect(engine.tick(now: mid).isEmpty)
        #expect(engine.remainingSeconds(at: mid) == 40)

        let end = start.addingTimeInterval(60)
        let endEvents = engine.tick(now: end)
        #expect(engine.phase == .completed)
        #expect(endEvents.contains(.didCompleteFocus(elapsedSeconds: 60, endedAt: end)))
        #expect(!endEvents.contains(where: { if case .didStartBreak = $0 { return true }; return false }))
    }

    @Test
    func onlySessionLifecycleEventsRequireASwiftDataSave() {
        #expect(
            !FocusTimerEvent.requiresStoreSave([
                .shouldScheduleNotification(start),
                .shouldCancelNotification,
                .didStartBreak(isLong: false, plannedDurationSeconds: 5),
            ])
        )
        #expect(
            FocusTimerEvent.requiresStoreSave([
                .didCompleteFocus(elapsedSeconds: 60, endedAt: start),
                .shouldCancelNotification,
            ])
        )
    }

    @Test
    func pauseExcludesStoppedTimeFromElapsed() {
        var engine = FocusTimerEngine(settings: FocusTimerSettings(focusSeconds: 120))
        _ = engine.startFocus(taskID: nil, now: start)

        let pauseAt = start.addingTimeInterval(30)
        _ = engine.pause(now: pauseAt)
        #expect(engine.phase == .pausedFocus)
        #expect(engine.elapsedSeconds(at: pauseAt) == 30)

        let later = pauseAt.addingTimeInterval(90)
        #expect(engine.elapsedSeconds(at: later) == 30)

        _ = engine.resume(now: later)
        let completeAt = later.addingTimeInterval(90)
        let events = engine.tick(now: completeAt)
        #expect(events.contains(.didCompleteFocus(elapsedSeconds: 120, endedAt: completeAt)))
    }

    @Test
    func cancelRecordsACancelledFocusEvent() {
        var engine = FocusTimerEngine(settings: FocusTimerSettings(focusSeconds: 60))
        _ = engine.startFocus(taskID: UUID(), now: start)
        let events = engine.cancel(now: start.addingTimeInterval(10))

        #expect(engine.phase == .idle)
        #expect(events.contains(.didCancelFocus(elapsedSeconds: 10, endedAt: start.addingTimeInterval(10))))
    }

    @Test
    func clockJumpCompletesUsingThePlannedEndDate() {
        var engine = FocusTimerEngine(settings: FocusTimerSettings(focusSeconds: 25 * 60))
        _ = engine.startFocus(taskID: nil, now: start)
        let jumped = start.addingTimeInterval(60 * 60)
        #expect(engine.elapsedSeconds(at: jumped) == 25 * 60)

        let events = engine.tick(now: jumped)
        #expect(engine.phase == .completed)
        #expect(events.contains(.didCompleteFocus(elapsedSeconds: 25 * 60, endedAt: jumped)))
    }

    @Test
    func automaticBreakStartsAfterFocus() {
        var settings = FocusTimerSettings(focusSeconds: 10, shortBreakSeconds: 5)
        settings.startBreaksAutomatically = true
        var engine = FocusTimerEngine(settings: settings)
        _ = engine.startFocus(taskID: nil, now: start)
        let events = engine.tick(now: start.addingTimeInterval(10))

        #expect(engine.phase == .runningBreak)
        #expect(events.contains(.didStartBreak(isLong: false, plannedDurationSeconds: 5)))
        #expect(!events.contains(where: { if case .didStartFocus = $0 { return true }; return false }))
    }

    @Test
    func manualBreakCanStartOrBeSkippedAfterFocus() {
        var engine = FocusTimerEngine(
            settings: FocusTimerSettings(focusSeconds: 10, shortBreakSeconds: 5)
        )
        _ = engine.startFocus(taskID: nil, now: start)
        let focusEvents = engine.tick(now: start.addingTimeInterval(10))

        #expect(engine.phase == .completed)
        #expect(!focusEvents.contains(where: { if case .didStartBreak = $0 { return true }; return false }))

        let breakEvents = engine.startBreak(now: start.addingTimeInterval(10))
        #expect(engine.phase == .runningBreak)
        #expect(breakEvents.contains(.didStartBreak(isLong: false, plannedDurationSeconds: 5)))

        var skippedEngine = FocusTimerEngine(settings: FocusTimerSettings(focusSeconds: 10))
        _ = skippedEngine.startFocus(taskID: nil, now: start)
        _ = skippedEngine.tick(now: start.addingTimeInterval(10))
        _ = skippedEngine.skipBreak()
        #expect(skippedEngine.phase == .idle)
    }

    @Test
    func automaticModeStartsLongBreakAtConfiguredInterval() {
        var settings = FocusTimerSettings(
            focusSeconds: 10,
            shortBreakSeconds: 5,
            longBreakSeconds: 20,
            sessionsBeforeLongBreak: 2
        )
        settings.startBreaksAutomatically = true
        var engine = FocusTimerEngine(settings: settings)

        _ = engine.startFocus(taskID: nil, now: start)
        _ = engine.tick(now: start.addingTimeInterval(10))
        _ = engine.tick(now: start.addingTimeInterval(15))
        _ = engine.startFocus(taskID: nil, now: start.addingTimeInterval(15))
        let events = engine.tick(now: start.addingTimeInterval(25))

        #expect(engine.phase == .runningBreak)
        #expect(engine.isLongBreak)
        #expect(events.contains(.didStartBreak(isLong: true, plannedDurationSeconds: 20)))
    }

    @Test
    func cancelingFocusRecordsABrokenTomatoAndDoesNotStartBreakOrNextFocus() {
        var engine = FocusTimerEngine(settings: FocusTimerSettings(focusSeconds: 60, shortBreakSeconds: 5))
        _ = engine.startFocus(taskID: UUID(), now: start)
        let events = engine.cancel(now: start.addingTimeInterval(10))

        #expect(engine.phase == .idle)
        #expect(engine.completedFocusCount == 0)
        #expect(events.contains(.didCancelFocus(elapsedSeconds: 10, endedAt: start.addingTimeInterval(10))))
        #expect(!events.contains(where: { if case .didStartBreak = $0 { return true }; return false }))
        #expect(!events.contains(where: { if case .didStartFocus = $0 { return true }; return false }))
    }
}
