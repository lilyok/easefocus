import Foundation
import SwiftData
import Testing
@testable import EaseFocus

private struct SilentNotifications: NotificationScheduling {
    func currentAccess() async -> NotificationAccess { .denied }
    func requestAuthorization() async -> Bool { false }
    func scheduleTimerFinished(at date: Date) async {}
    func cancelTimerFinished() {}
    func announcePeriodFinished(isBreak: Bool) {}
}

private final class RecordingNotifications: NotificationScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var scheduled: [Date] = []
    private var announcements: [Bool] = []

    var scheduledDates: [Date] {
        lock.withLock { scheduled }
    }

    var announcementIsBreaks: [Bool] {
        lock.withLock { announcements }
    }

    func currentAccess() async -> NotificationAccess { .allowed }
    func requestAuthorization() async -> Bool { false }

    func scheduleTimerFinished(at date: Date) async {
        lock.withLock { scheduled.append(date) }
    }

    func cancelTimerFinished() {}

    func announcePeriodFinished(isBreak: Bool) {
        lock.withLock { announcements.append(isBreak) }
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
        first.settings.startBreaksAutomatically = true

        let relaunched = FocusTimerController(
            settings: FocusTimerSettings(focusSeconds: 99 * 60),
            notifications: SilentNotifications(),
            defaults: defaults
        )

        #expect(relaunched.settings.focusSeconds == 15 * 60)
        #expect(relaunched.settings.shortBreakSeconds == 3 * 60)
        #expect(relaunched.settings.startBreaksAutomatically)
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

        controller.tick(now: start.addingTimeInterval(60))
        #expect(first.status == .pending)
        #expect(controller.engine.phase == .completed)
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
            settings: FocusTimerSettings(focusSeconds: 60),
            notifications: recorder,
            defaults: defaults
        )
        controller.attach(modelContext: container.mainContext, now: start)
        controller.startFocus(task: nil, now: start)
        controller.tick(now: start.addingTimeInterval(60))

        #expect(recorder.announcementIsBreaks == [false])
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
    }

    private func uniqueDefaults() -> (UserDefaults, String) {
        let suiteName = "easefocus.tests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    private func waitForScheduledDate(
        in recorder: RecordingNotifications,
        timeout: Duration = .seconds(1)
    ) async throws -> Date {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if let date = recorder.scheduledDates.last {
                return date
            }
            await Task.yield()
        }
        Issue.record("Timed out waiting for a restored timer notification")
        return .distantPast
    }
}
