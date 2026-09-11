import Foundation
import SwiftData
import Testing
@testable import EaseFocus

private struct SilentNotifications: NotificationScheduling {
    func currentAccess() async -> NotificationAccess { .denied }
    func requestAuthorization() async -> Bool { false }
    func scheduleTimerFinished(at date: Date, playsSound: Bool) async {}
    func cancelTimerFinished() {}
    func announcePeriodFinished(isBreak: Bool, playsSound: Bool) {}
}

private final class RecordingNotifications: NotificationScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var scheduled: [(date: Date, playsSound: Bool)] = []
    private var announcements: [(isBreak: Bool, playsSound: Bool)] = []

    var scheduledDates: [Date] {
        lock.withLock { scheduled.map(\.date) }
    }

    var scheduledPlaySounds: [Bool] {
        lock.withLock { scheduled.map(\.playsSound) }
    }

    var announcementIsBreaks: [Bool] {
        lock.withLock { announcements.map(\.isBreak) }
    }

    var announcementPlaySounds: [Bool] {
        lock.withLock { announcements.map(\.playsSound) }
    }

    func currentAccess() async -> NotificationAccess { .allowed }
    func requestAuthorization() async -> Bool { false }

    func scheduleTimerFinished(at date: Date, playsSound: Bool) async {
        lock.withLock { scheduled.append((date, playsSound)) }
    }

    func cancelTimerFinished() {}

    func announcePeriodFinished(isBreak: Bool, playsSound: Bool) {
        lock.withLock { announcements.append((isBreak, playsSound)) }
    }
}

struct FocusTimerControllerTests {
    @Test
    @MainActor
    func restoresSavedSettingsOnRelaunch() {
        let (defaults, suiteName) = uniqueDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = FocusTimerController(
            settings: FocusTimerSettings(focusSeconds: 25 * 60),
            notifications: SilentNotifications(),
            defaults: defaults
        )
        first.settings.focusSeconds = 15 * 60
        first.settings.shortBreakSeconds = 3 * 60
        first.settings.sessionsBeforeLongBreak = 3
        first.settings.startBreaksAutomatically = true
        first.settings.playsCompletionSound = false

        let relaunched = FocusTimerController(
            settings: FocusTimerSettings(focusSeconds: 99 * 60),
            notifications: SilentNotifications(),
            defaults: defaults
        )

        #expect(relaunched.settings.focusSeconds == 15 * 60)
        #expect(relaunched.settings.shortBreakSeconds == 3 * 60)
        #expect(relaunched.settings.sessionsBeforeLongBreak == 3)
        #expect(relaunched.settings.startBreaksAutomatically)
        #expect(!relaunched.settings.playsCompletionSound)
    }

    @Test
    @MainActor
    func marksOnlyTheStartedTaskActive() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let first = PlanTask(title: "One", position: 0)
        let second = PlanTask(title: "Two", position: 1)
        context.insert(GoalPlan(title: "Plan", tasks: [first, second]))
        try context.save()

        let (defaults, suiteName) = uniqueDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let controller = FocusTimerController(
            notifications: SilentNotifications(),
            defaults: defaults
        )
        controller.attach(modelContext: context)

        controller.startFocus(task: first)
        #expect(first.status == .active)
        #expect(second.status == .pending)

        controller.startFocus(task: second)
        #expect(first.status == .active)
        #expect(second.status == .pending)
        #expect(controller.engine.taskID == first.id)
    }

    @Test
    @MainActor
    func revertsTheTaskOnCancel() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let first = PlanTask(title: "One", position: 0)
        context.insert(GoalPlan(title: "Plan", tasks: [first]))
        try context.save()

        let (defaults, suiteName) = uniqueDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let controller = FocusTimerController(
            notifications: SilentNotifications(),
            defaults: defaults
        )
        controller.attach(modelContext: context)
        controller.startFocus(task: first)
        controller.cancel()

        #expect(first.status == .pending)
        #expect(controller.engine.phase == .idle)
    }

    @Test
    @MainActor
    func cancelRecordsABrokenTomatoWithoutStartingTheNextFocus() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let first = PlanTask(title: "One", position: 0)
        context.insert(GoalPlan(title: "Plan", tasks: [first]))
        try context.save()

        let (defaults, suiteName) = uniqueDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let controller = FocusTimerController(
            notifications: SilentNotifications(),
            defaults: defaults
        )
        controller.attach(modelContext: context)
        controller.startFocus(task: first)
        controller.cancel()

        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        #expect(sessions.contains { $0.outcome == .cancelled })
        #expect(first.brokenSessionCount == 1)
        #expect(first.completedSessionCount == 0)
        #expect(controller.engine.phase == .idle)
        #expect(controller.engine.canStartFocus)
    }

    @Test
    @MainActor
    func revertsTheTaskWhenFocusCompletes() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let first = PlanTask(title: "One", position: 0)
        context.insert(GoalPlan(title: "Plan", tasks: [first]))
        try context.save()

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let (defaults, suiteName) = uniqueDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let controller = FocusTimerController(
            settings: FocusTimerSettings(focusSeconds: 60),
            notifications: SilentNotifications(),
            defaults: defaults
        )
        controller.attach(modelContext: context, now: start)
        controller.startFocus(task: first, now: start)
        #expect(first.status == .active)
        #expect(!controller.isSaveAlertPresented)

        controller.tick(now: start.addingTimeInterval(20))
        #expect(controller.engine.phase == .runningFocus)
        #expect(controller.lastSaveErrorMessage == nil)
        #expect(!controller.isSaveAlertPresented)

        controller.tick(now: start.addingTimeInterval(60))
        #expect(first.status == .pending)
        #expect(controller.engine.phase == .completed)
        #expect(controller.lastSaveErrorMessage == nil)
        #expect(!controller.isSaveAlertPresented)
    }

    @Test
    @MainActor
    func automaticModeStartsBreakWhenFocusCompletes() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let (defaults, suiteName) = uniqueDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var settings = FocusTimerSettings(focusSeconds: 60, shortBreakSeconds: 5)
        settings.startBreaksAutomatically = true
        let controller = FocusTimerController(
            settings: settings,
            notifications: SilentNotifications(),
            defaults: defaults
        )
        controller.attach(modelContext: container.mainContext, now: start)
        controller.startFocus(task: nil, now: start)

        controller.tick(now: start.addingTimeInterval(60))

        #expect(controller.engine.phase == .runningBreak)
        #expect(controller.engine.remainingSeconds == 5)
    }

    @Test
    @MainActor
    func manualModePersistsCompletedStateAcrossRelaunch() throws {
        let (defaults, suiteName) = uniqueDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let firstContainer = try EaseFocusStore.inMemoryContainer()
        let first = FocusTimerController(
            settings: FocusTimerSettings(focusSeconds: 60, shortBreakSeconds: 5),
            notifications: SilentNotifications(),
            defaults: defaults
        )
        first.attach(modelContext: firstContainer.mainContext, now: start)
        first.startFocus(task: nil, now: start)
        first.tick(now: start.addingTimeInterval(60))
        #expect(first.engine.phase == .completed)

        let restoredContainer = try EaseFocusStore.inMemoryContainer()
        let relaunched = FocusTimerController(
            notifications: SilentNotifications(),
            defaults: defaults
        )
        relaunched.attach(
            modelContext: restoredContainer.mainContext,
            now: start.addingTimeInterval(61)
        )

        #expect(!relaunched.settings.startBreaksAutomatically)
        #expect(relaunched.engine.phase == .completed)

        relaunched.startBreak(now: start.addingTimeInterval(61))
        #expect(relaunched.engine.phase == .runningBreak)
    }

    @Test
    @MainActor
    func announcesWhenFocusCompletes() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let (defaults, suiteName) = uniqueDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let recorder = RecordingNotifications()
        let controller = FocusTimerController(
            settings: FocusTimerSettings(focusSeconds: 60, playsCompletionSound: false),
            notifications: recorder,
            defaults: defaults
        )
        controller.attach(modelContext: container.mainContext, now: start)
        controller.startFocus(task: nil, now: start)
        controller.tick(now: start.addingTimeInterval(60))

        #expect(recorder.announcementIsBreaks == [false])
        #expect(recorder.announcementPlaySounds == [false])
    }

    @Test
    @MainActor
    func reschedulesRunningNotificationWhenSoundToggleChanges() async throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let (defaults, suiteName) = uniqueDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let recorder = RecordingNotifications()
        let controller = FocusTimerController(
            settings: FocusTimerSettings(focusSeconds: 60, playsCompletionSound: true),
            notifications: recorder,
            defaults: defaults
        )
        controller.attach(modelContext: container.mainContext, now: start)
        controller.startFocus(task: nil, now: start)

        let first = try await waitForScheduled(in: recorder, playsSound: true)
        #expect(first.date == start.addingTimeInterval(60))

        let countBeforeMute = recorder.scheduledDates.count
        var muted = controller.settings
        muted.playsCompletionSound = false
        controller.settings = muted

        let second = try await waitForScheduled(
            in: recorder,
            playsSound: false,
            afterCount: countBeforeMute
        )
        #expect(second.date == first.date)
    }

    @Test
    @MainActor
    func reschedulesNotificationWhenRestoringARunningTimer() async throws {
        let (defaults, suiteName) = uniqueDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let focusSeconds = 25 * 60

        let firstContainer = try EaseFocusStore.inMemoryContainer()
        let first = FocusTimerController(
            settings: FocusTimerSettings(focusSeconds: focusSeconds),
            notifications: SilentNotifications(),
            defaults: defaults
        )
        first.attach(modelContext: firstContainer.mainContext, now: start)
        first.startFocus(task: nil, now: start)

        let recorder = RecordingNotifications()
        let restoredContainer = try EaseFocusStore.inMemoryContainer()
        let relaunched = FocusTimerController(
            notifications: recorder,
            defaults: defaults
        )
        relaunched.attach(
            modelContext: restoredContainer.mainContext,
            now: start.addingTimeInterval(5)
        )

        let scheduled = try await waitForScheduledDate(in: recorder)
        #expect(relaunched.engine.phase == .runningFocus)
        #expect(scheduled == start.addingTimeInterval(TimeInterval(focusSeconds)))
        #expect(recorder.scheduledPlaySounds.last == true)
    }

    private func uniqueDefaults() -> (UserDefaults, String) {
        let suiteName = "easefocus.tests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    private func waitForScheduledDate(
        in recorder: RecordingNotifications,
        timeout: Duration = .seconds(5)
    ) async throws -> Date {
        try await waitForScheduled(in: recorder, playsSound: true, timeout: timeout).date
    }

    private func waitForScheduled(
        in recorder: RecordingNotifications,
        playsSound: Bool,
        afterCount: Int = 0,
        timeout: Duration = .seconds(5)
    ) async throws -> (date: Date, playsSound: Bool) {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            let dates = recorder.scheduledDates
            let sounds = recorder.scheduledPlaySounds
            if dates.count > afterCount {
                for index in stride(from: dates.count - 1, through: afterCount, by: -1) {
                    if sounds[index] == playsSound {
                        return (dates[index], sounds[index])
                    }
                }
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Timed out waiting for scheduled notification playsSound=\(playsSound)")
        return (.distantPast, playsSound)
    }
}
