import Foundation
import SwiftData

@MainActor
@Observable
final class FocusTimerController {
    private(set) var engine: FocusTimerEngine
    private(set) var notificationAccess: NotificationAccess = .notDetermined
    private var openSession: FocusSession?
    private var modelContext: ModelContext?
    private let notifications: any NotificationScheduling
    private let defaults: UserDefaults
    private let stateKey = "easefocus.timer.engine"

    init(
        settings: FocusTimerSettings = FocusTimerSettings(),
        notifications: any NotificationScheduling = UserNotificationScheduler(),
        defaults: UserDefaults = .standard
    ) {
        self.notifications = notifications
        self.defaults = defaults
        if let data = defaults.data(forKey: stateKey),
           let saved = try? JSONDecoder().decode(FocusTimerEngine.self, from: data) {
            // Keep saved durations and phase. Initializer defaults are first-launch only.
            engine = saved
        } else {
            engine = FocusTimerEngine(settings: settings)
        }
    }

    var settings: FocusTimerSettings {
        get { engine.settings }
        set {
            engine.settings = newValue
            persistEngine()
        }
    }

    func attach(modelContext: ModelContext, now: Date = .now) {
        self.modelContext = modelContext
        closeDanglingSessions(now: now)
        var events = engine.tick(now: now)
        if events.isEmpty, engine.isRunning, let periodEndsAt = engine.periodEndsAt {
            events.append(.shouldScheduleNotification(periodEndsAt))
        }
        apply(events, now: now)
    }

    func startFocus(task: PlanTask?, now: Date = .now) {
        apply(engine.startFocus(taskID: task?.id, now: now), now: now, startedTask: task)
        Task { await requestAccessAndRescheduleIfRunning() }
    }

    func pause(now: Date = .now) {
        apply(engine.pause(now: now), now: now)
    }

    func resume(now: Date = .now) {
        apply(engine.resume(now: now), now: now)
        Task { await requestAccessAndRescheduleIfRunning() }
    }

    func cancel(now: Date = .now) {
        apply(engine.cancel(now: now), now: now)
    }

    func startBreak(now: Date = .now) {
        apply(engine.startBreak(now: now), now: now)
        Task { await requestAccessAndRescheduleIfRunning() }
    }

    func skipBreak() {
        apply(engine.skipBreak(), now: .now)
    }

    func tick(now: Date = .now) {
        apply(engine.tick(now: now), now: now)
    }

    func requestNotificationPermission() async -> Bool {
        await notifications.requestAuthorization()
    }

    func refreshNotificationAccess() async {
        let access = await notifications.currentAccess()
        if access != notificationAccess {
            notificationAccess = access
        }
    }

    private func requestAccessAndRescheduleIfRunning() async {
        await refreshNotificationAccess()
        if notificationAccess == .notDetermined {
            _ = await notifications.requestAuthorization()
            await refreshNotificationAccess()
        }
        guard engine.isRunning, let periodEndsAt = engine.periodEndsAt else {
            return
        }
        await notifications.scheduleTimerFinished(at: periodEndsAt)
    }

    private func apply(_ events: [FocusTimerEvent], now: Date, startedTask: PlanTask? = nil) {
        for event in events {
            switch event {
            case .didStartFocus(let taskID, let planned, let startedAt):
                let session = FocusSession(startedAt: startedAt, plannedDurationSeconds: planned)
                if let task = startedTask ?? taskID.flatMap(task(withID:)) {
                    session.task = task
                    task.status = .active
                    task.updatedAt = startedAt
                }
                modelContext?.insert(session)
                openSession = session
            case .didCompleteFocus(let elapsed, let endedAt):
                revertActiveTask(at: endedAt)
                openSession?.finish(outcome: .completed, at: endedAt, elapsedSeconds: elapsed)
                openSession = nil
                notifications.announcePeriodFinished(isBreak: false)
            case .didCancelFocus(let elapsed, let endedAt):
                revertActiveTask(at: endedAt)
                openSession?.finish(outcome: .cancelled, at: endedAt, elapsedSeconds: elapsed)
                openSession = nil
            case .didInterruptFocus(let elapsed, let endedAt):
                revertActiveTask(at: endedAt)
                openSession?.finish(outcome: .interrupted, at: endedAt, elapsedSeconds: elapsed)
                openSession = nil
            case .didStartBreak:
                break
            case .didCompleteBreak:
                notifications.announcePeriodFinished(isBreak: true)
            case .shouldScheduleNotification(let date):
                Task { await notifications.scheduleTimerFinished(at: date) }
            case .shouldCancelNotification:
                notifications.cancelTimerFinished()
            }
        }
        persistEngine()
        save()
    }

    private func closeDanglingSessions(now: Date) {
        guard let modelContext else {
            return
        }

        let descriptor = FetchDescriptor<FocusSession>()
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        for session in sessions where session.isOpen {
            if engine.phase == .runningFocus || engine.phase == .pausedFocus {
                openSession = session
            } else {
                session.finish(outcome: .interrupted, at: now, elapsedSeconds: session.elapsedSeconds)
                revertTask(session.task, at: now)
            }
        }
    }

    private func revertActiveTask(at date: Date) {
        revertTask(openSession?.task, at: date)
    }

    private func revertTask(_ task: PlanTask?, at date: Date) {
        guard let task, task.status == .active else {
            return
        }
        task.status = .pending
        task.updatedAt = date
    }

    private func task(withID id: UUID) -> PlanTask? {
        guard let modelContext else {
            return nil
        }
        let matchID = id
        let descriptor = FetchDescriptor<PlanTask>(
            predicate: #Predicate<PlanTask> { $0.id == matchID }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func persistEngine() {
        if let data = try? JSONEncoder().encode(engine) {
            defaults.set(data, forKey: stateKey)
        }
    }

    private func save() {
        try? modelContext?.save()
    }
}
