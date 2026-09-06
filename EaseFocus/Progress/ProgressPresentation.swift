import Foundation

nonisolated struct ProgressSessionRecord: Equatable, Sendable {
    var id: UUID
    var startedAt: Date
    var elapsedSeconds: Int
    var outcome: SessionOutcome?
    var taskTitle: String?
    var planID: UUID?
}

nonisolated struct ProgressPlanRecord: Equatable, Sendable {
    var id: UUID
    var title: String
    var status: PlanStatus
    var taskStatuses: [TaskStatus]
}

nonisolated struct ProgressWeekInterval: Equatable, Sendable {
    var start: Date
    var end: Date

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

nonisolated struct ProgressCountSummary: Equatable, Sendable {
    var completedCount: Int
    var brokenCount: Int
    var focusedSeconds: Int
}

nonisolated struct ProgressMomentumDay: Equatable, Identifiable, Sendable {
    var date: Date
    var weekdaySymbol: String
    var hasCompletedFocus: Bool
    var isToday: Bool

    var id: Date { date }
}

nonisolated struct ProgressPlanRow: Equatable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var status: PlanStatus
    var openTaskCount: Int
    var doneTaskCount: Int
    var completedSessionCount: Int
    var focusedSeconds: Int

    var isCompletedPlan: Bool {
        status == .completed
    }
}

nonisolated struct ProgressHistoryItem: Equatable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var detail: String
}

nonisolated enum ProgressPresentation {
    static func showsFullEmptyState(sessionCount: Int, planRowCount: Int) -> Bool {
        sessionCount == 0 && planRowCount == 0
    }

    static func weekInterval(containing date: Date, calendar: Calendar) -> ProgressWeekInterval {
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return ProgressWeekInterval(start: interval.start, end: interval.end)
        }
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return ProgressWeekInterval(start: start, end: end)
    }

    static func summary(
        sessions: [ProgressSessionRecord],
        in interval: ProgressWeekInterval
    ) -> ProgressCountSummary {
        counts(in: sessions.filter { interval.contains($0.startedAt) })
    }

    static func todaySummary(
        sessions: [ProgressSessionRecord],
        now: Date,
        calendar: Calendar
    ) -> ProgressCountSummary {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let today = ProgressWeekInterval(start: start, end: end)
        return summary(sessions: sessions, in: today)
    }

    static func openTaskCount(taskStatuses: [TaskStatus]) -> Int {
        taskStatuses.filter { $0 == .pending || $0 == .active }.count
    }

    static func doneTaskCount(taskStatuses: [TaskStatus]) -> Int {
        taskStatuses.filter { $0 == .completed }.count
    }

    static func momentumDays(
        sessions: [ProgressSessionRecord],
        now: Date,
        calendar: Calendar
    ) -> [ProgressMomentumDay] {
        let week = weekInterval(containing: now, calendar: calendar)
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: week.start) else {
                return nil
            }
            let dayStart = calendar.startOfDay(for: date)
            let weekdayIndex = calendar.component(.weekday, from: dayStart) - 1
            let symbol = symbols.indices.contains(weekdayIndex) ? symbols[weekdayIndex] : ""
            let hasCompletedFocus = sessions.contains { session in
                session.outcome == .completed
                    && calendar.isDate(session.startedAt, inSameDayAs: dayStart)
            }
            return ProgressMomentumDay(
                date: dayStart,
                weekdaySymbol: symbol,
                hasCompletedFocus: hasCompletedFocus,
                isToday: calendar.isDate(dayStart, inSameDayAs: now)
            )
        }
    }

    static func planRows(
        plans: [ProgressPlanRecord],
        sessions: [ProgressSessionRecord],
        week: ProgressWeekInterval
    ) -> [ProgressPlanRow] {
        let rows = plans.compactMap { plan -> ProgressPlanRow? in
            let weekSessions = sessions.filter {
                $0.planID == plan.id && week.contains($0.startedAt)
            }
            let completed = weekSessions.filter { $0.outcome == .completed }
            switch plan.status {
            case .active, .paused:
                break
            case .completed:
                guard !weekSessions.isEmpty else {
                    return nil
                }
            case .archived:
                return nil
            }
            return ProgressPlanRow(
                id: plan.id,
                title: plan.title,
                status: plan.status,
                openTaskCount: openTaskCount(taskStatuses: plan.taskStatuses),
                doneTaskCount: doneTaskCount(taskStatuses: plan.taskStatuses),
                completedSessionCount: completed.count,
                focusedSeconds: completed.reduce(0) { $0 + max(0, $1.elapsedSeconds) }
            )
        }
        return rows.filter { !$0.isCompletedPlan } + rows.filter(\.isCompletedPlan)
    }

    static func historyItems(
        sessions: [ProgressSessionRecord],
        locale: Locale
    ) -> [ProgressHistoryItem] {
        sessions.map { session in
            ProgressHistoryItem(
                id: session.id,
                title: session.taskTitle ?? ProgressCopy.quickFocusTitle.localized(locale),
                detail: historyDetail(session, locale: locale)
            )
        }
    }

    static func weekTitle(
        week: ProgressWeekInterval,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let endDay = calendar.date(byAdding: .day, value: 6, to: week.start) ?? week.start
        var format = Date.FormatStyle(date: .abbreviated, time: .omitted)
        format.calendar = calendar
        format.locale = locale
        return "\(week.start.formatted(format)) – \(endDay.formatted(format))"
    }

    static func countLine(
        _ summary: ProgressCountSummary,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        ProgressCopy.countLine(
            completed: summary.completedCount,
            broken: summary.brokenCount,
            focused: FocusDurationFormat.clock(summary.focusedSeconds)
        ).localized(locale)
    }

    static func planTaskLine(open: Int, done: Int, locale: Locale = .autoupdatingCurrent) -> String {
        ProgressCopy.planTaskLine(open: open, done: done).localized(locale)
    }

    static func planWeekLine(
        completed: Int,
        focusedSeconds: Int,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        ProgressCopy.planWeekLine(
            completed: completed,
            focused: FocusDurationFormat.clock(focusedSeconds)
        ).localized(locale)
    }

    static func momentumAccessibilityLabel(
        _ day: ProgressMomentumDay,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        if day.hasCompletedFocus {
            if day.isToday {
                return ProgressCopy.momentumCompletedToday(weekday: day.weekdaySymbol).localized(locale)
            }
            return ProgressCopy.momentumCompleted(weekday: day.weekdaySymbol).localized(locale)
        }
        if day.isToday {
            return ProgressCopy.momentumNoneToday(weekday: day.weekdaySymbol).localized(locale)
        }
        return ProgressCopy.momentumNone(weekday: day.weekdaySymbol).localized(locale)
    }

    private static func counts(in sessions: [ProgressSessionRecord]) -> ProgressCountSummary {
        let completed = sessions.filter { $0.outcome == .completed }
        let broken = sessions.filter { $0.outcome?.isBroken == true }
        return ProgressCountSummary(
            completedCount: completed.count,
            brokenCount: broken.count,
            focusedSeconds: completed.reduce(0) { $0 + max(0, $1.elapsedSeconds) }
        )
    }

    private static func historyDetail(_ session: ProgressSessionRecord, locale: Locale) -> String {
        let outcome = (session.outcome?.progressTitle ?? ProgressCopy.openSession).localized(locale)
        var format = Date.FormatStyle(date: .abbreviated, time: .shortened)
        format.locale = locale
        let when = session.startedAt.formatted(format)
        return ProgressCopy.historyDetail(
            outcome: outcome,
            duration: FocusDurationFormat.clock(session.elapsedSeconds),
            when: when
        ).localized(locale)
    }
}

nonisolated enum ProgressAccessibilityIdentifier {
    static let weekSummary = "progressWeekSummary"
    static let momentum = "progressMomentum"

    static func planRow(for id: UUID) -> String {
        "progressPlan-\(id.uuidString)"
    }
}

nonisolated enum ProgressCopy {
    static let navigationTitle = AppCopy.progress
    static let thisWeek = LocalizedCopy("This week")
    static let today = AppCopy.today
    static let history = LocalizedCopy("History")
    static let plans = AppCopy.plans
    static let emptyTitle = LocalizedCopy("No sessions yet")
    static let emptyDescription = LocalizedCopy(
        "Completed and broken focus sessions will show up here."
    )
    static let completedPlan = LocalizedCopy("Completed")
    static let quickFocusTitle = LocalizedCopy("Quick focus")
    static let openSession = LocalizedCopy("open")

    static func countLine(completed: Int, broken: Int, focused: String) -> LocalizedCopy {
        LocalizedCopy(
            format: "\(completed) completed · \(broken) broken · \(focused) focused",
            english: "\(completed) completed · \(broken) broken · \(focused) focused"
        )
    }

    static func planTaskLine(open: Int, done: Int) -> LocalizedCopy {
        LocalizedCopy(format: "\(open) open · \(done) done", english: "\(open) open · \(done) done")
    }

    static func planWeekLine(completed: Int, focused: String) -> LocalizedCopy {
        LocalizedCopy(
            format: "\(completed) completed this week · \(focused) focused",
            english: "\(completed) completed this week · \(focused) focused"
        )
    }

    static func momentumCompletedToday(weekday: String) -> LocalizedCopy {
        LocalizedCopy(
            format: "\(weekday), completed focus, today",
            english: "\(weekday), completed focus, today"
        )
    }

    static func momentumNoneToday(weekday: String) -> LocalizedCopy {
        LocalizedCopy(
            format: "\(weekday), no completed focus, today",
            english: "\(weekday), no completed focus, today"
        )
    }

    static func momentumCompleted(weekday: String) -> LocalizedCopy {
        LocalizedCopy(
            format: "\(weekday), completed focus",
            english: "\(weekday), completed focus"
        )
    }

    static func momentumNone(weekday: String) -> LocalizedCopy {
        LocalizedCopy(
            format: "\(weekday), no completed focus",
            english: "\(weekday), no completed focus"
        )
    }

    static func historyDetail(outcome: String, duration: String, when: String) -> LocalizedCopy {
        LocalizedCopy(
            format: "\(outcome) · \(duration) · \(when)",
            english: "\(outcome) · \(duration) · \(when)"
        )
    }
}
