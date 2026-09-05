import Foundation
import Testing
@testable import EaseFocus

struct ProgressPresentationTests {
    private let planA = UUID()
    private let planB = UUID()
    private let sessionA = UUID()
    private let sessionB = UUID()
    private let sessionC = UUID()

    @Test
    func emptyWeekHasZeroCountsAndNoMomentumDays() {
        let calendar = gregorianCalendar(firstWeekday: 1)
        let now = date(2025, 1, 8, 12, 0, calendar: calendar)
        let week = ProgressPresentation.weekInterval(containing: now, calendar: calendar)
        let summary = ProgressPresentation.summary(sessions: [], in: week)
        let days = ProgressPresentation.momentumDays(sessions: [], now: now, calendar: calendar)

        #expect(summary == ProgressCountSummary(completedCount: 0, brokenCount: 0, focusedSeconds: 0))
        #expect(days.count == 7)
        #expect(days.allSatisfy { !$0.hasCompletedFocus })
        #expect(ProgressPresentation.countLine(summary) == "0 completed · 0 broken · 0:00 focused")
        #expect(ProgressPresentation.planRows(plans: [], sessions: [], week: week).isEmpty)
    }

    @Test
    func sundayFirstWeekIncludesMidnightSundayAndExcludesSaturdayNight() {
        let calendar = gregorianCalendar(firstWeekday: 1)
        let now = date(2025, 1, 8, 12, 0, calendar: calendar)
        let week = ProgressPresentation.weekInterval(containing: now, calendar: calendar)

        #expect(calendar.component(.weekday, from: week.start) == 1)
        #expect(week.contains(date(2025, 1, 5, 0, 1, calendar: calendar)))
        #expect(!week.contains(date(2025, 1, 4, 23, 59, calendar: calendar)))
        #expect(week.contains(date(2025, 1, 11, 23, 59, calendar: calendar)))
        #expect(!week.contains(date(2025, 1, 12, 0, 1, calendar: calendar)))

        let inside = session(
            id: sessionA,
            startedAt: date(2025, 1, 5, 0, 1, calendar: calendar),
            elapsedSeconds: 60,
            outcome: .completed
        )
        let before = session(
            id: sessionB,
            startedAt: date(2025, 1, 4, 23, 59, calendar: calendar),
            elapsedSeconds: 1_200,
            outcome: .completed
        )
        let after = session(
            id: sessionC,
            startedAt: date(2025, 1, 12, 0, 1, calendar: calendar),
            elapsedSeconds: 1_800,
            outcome: .completed
        )
        let summary = ProgressPresentation.summary(sessions: [inside, before, after], in: week)
        #expect(summary.completedCount == 1)
        #expect(summary.focusedSeconds == 60)
    }

    @Test
    func mondayFirstWeekStartsMondayAndDropsSundayNight() {
        let calendar = gregorianCalendar(firstWeekday: 2)
        let now = date(2025, 1, 8, 12, 0, calendar: calendar)
        let week = ProgressPresentation.weekInterval(containing: now, calendar: calendar)

        #expect(calendar.component(.weekday, from: week.start) == 2)
        #expect(!week.contains(date(2025, 1, 5, 23, 59, calendar: calendar)))
        #expect(week.contains(date(2025, 1, 6, 0, 1, calendar: calendar)))
        #expect(week.contains(date(2025, 1, 12, 23, 59, calendar: calendar)))
        #expect(!week.contains(date(2025, 1, 13, 0, 1, calendar: calendar)))
    }

    @Test
    func countsCompletedAndBrokenSeparatelyAndSumsOnlyCompletedElapsedTime() {
        let calendar = gregorianCalendar(firstWeekday: 1)
        let now = date(2025, 1, 8, 15, 0, calendar: calendar)
        let week = ProgressPresentation.weekInterval(containing: now, calendar: calendar)
        let sessions = [
            session(
                id: sessionA,
                startedAt: date(2025, 1, 6, 9, 0, calendar: calendar),
                elapsedSeconds: 1_500,
                outcome: .completed,
                planID: planA
            ),
            session(
                id: sessionB,
                startedAt: date(2025, 1, 7, 9, 0, calendar: calendar),
                elapsedSeconds: 400,
                outcome: .cancelled,
                planID: planA
            ),
            session(
                id: sessionC,
                startedAt: date(2025, 1, 8, 9, 0, calendar: calendar),
                elapsedSeconds: 200,
                outcome: .interrupted,
                planID: planA
            ),
            session(
                id: UUID(),
                startedAt: date(2025, 1, 8, 10, 0, calendar: calendar),
                elapsedSeconds: 90,
                outcome: nil,
                planID: planA
            ),
        ]

        let summary = ProgressPresentation.summary(sessions: sessions, in: week)
        #expect(summary.completedCount == 1)
        #expect(summary.brokenCount == 2)
        #expect(summary.focusedSeconds == 1_500)
        #expect(ProgressPresentation.countLine(summary) == "1 completed · 2 broken · 25:00 focused")
    }

    @Test
    func todaySummaryUsesStartOfDayAndDoesNotIncludeYesterday() {
        let calendar = gregorianCalendar(firstWeekday: 1)
        let now = date(2025, 1, 8, 0, 30, calendar: calendar)
        let sessions = [
            session(
                id: sessionA,
                startedAt: date(2025, 1, 8, 0, 5, calendar: calendar),
                elapsedSeconds: 120,
                outcome: .completed
            ),
            session(
                id: sessionB,
                startedAt: date(2025, 1, 7, 23, 50, calendar: calendar),
                elapsedSeconds: 900,
                outcome: .completed
            ),
        ]
        let today = ProgressPresentation.todaySummary(sessions: sessions, now: now, calendar: calendar)
        #expect(today.completedCount == 1)
        #expect(today.focusedSeconds == 120)
    }

    @Test
    func momentumMarksOnlyDaysWithCompletedFocus() {
        let calendar = gregorianCalendar(firstWeekday: 1)
        let now = date(2025, 1, 8, 12, 0, calendar: calendar)
        let sessions = [
            session(
                id: sessionA,
                startedAt: date(2025, 1, 6, 8, 0, calendar: calendar),
                elapsedSeconds: 600,
                outcome: .completed
            ),
            session(
                id: sessionB,
                startedAt: date(2025, 1, 7, 8, 0, calendar: calendar),
                elapsedSeconds: 120,
                outcome: .cancelled
            ),
            session(
                id: sessionC,
                startedAt: date(2025, 1, 8, 8, 0, calendar: calendar),
                elapsedSeconds: 90,
                outcome: .interrupted
            ),
        ]
        let days = ProgressPresentation.momentumDays(sessions: sessions, now: now, calendar: calendar)
        let completedDates = days.filter(\.hasCompletedFocus).map(\.date)
        #expect(completedDates == [calendar.startOfDay(for: date(2025, 1, 6, 8, 0, calendar: calendar))])
        #expect(days.contains { $0.isToday && calendar.isDate($0.date, inSameDayAs: now) })
        #expect(calendar.component(.weekday, from: days[0].date) == calendar.firstWeekday)
    }

    @Test
    func planRowsMatchOpenAndDoneCountsAndIgnoreOtherPlans() {
        let calendar = gregorianCalendar(firstWeekday: 1)
        let now = date(2025, 1, 8, 12, 0, calendar: calendar)
        let week = ProgressPresentation.weekInterval(containing: now, calendar: calendar)
        let plans = [
            ProgressPlanRecord(
                id: planA,
                title: "Spanish greetings",
                status: .active,
                taskStatuses: [.pending, .active, .completed, .archived]
            ),
            ProgressPlanRecord(
                id: planB,
                title: "Guitar practice",
                status: .active,
                taskStatuses: [.pending, .pending]
            ),
        ]
        let sessions = [
            session(
                id: sessionA,
                startedAt: date(2025, 1, 7, 10, 0, calendar: calendar),
                elapsedSeconds: 600,
                outcome: .completed,
                taskTitle: "Practice hola",
                planID: planA
            ),
            session(
                id: sessionB,
                startedAt: date(2025, 1, 7, 11, 0, calendar: calendar),
                elapsedSeconds: 1_200,
                outcome: .completed,
                taskTitle: "Warm up",
                planID: planB
            ),
            session(
                id: sessionC,
                startedAt: date(2025, 1, 7, 12, 0, calendar: calendar),
                elapsedSeconds: 90,
                outcome: .cancelled,
                planID: planA
            ),
        ]

        let rows = ProgressPresentation.planRows(plans: plans, sessions: sessions, week: week)
        #expect(rows.map(\.id) == [planA, planB])
        #expect(rows[0].openTaskCount == 2)
        #expect(rows[0].doneTaskCount == 1)
        #expect(rows[0].completedSessionCount == 1)
        #expect(rows[0].focusedSeconds == 600)
        #expect(rows[1].openTaskCount == 2)
        #expect(rows[1].doneTaskCount == 0)
        #expect(rows[1].completedSessionCount == 1)
        #expect(rows[1].focusedSeconds == 1_200)
        #expect(ProgressPresentation.planTaskLine(open: 2, done: 1) == "2 open · 1 done")
        #expect(ProgressPresentation.openTaskCount(taskStatuses: [.pending, .active, .completed]) == 2)
        #expect(ProgressPresentation.doneTaskCount(taskStatuses: [.pending, .active, .completed]) == 1)
    }

    @Test
    func activePlansAppearWithoutWeeklySessionsAndCompletedPlansAreLabeled() {
        let calendar = gregorianCalendar(firstWeekday: 1)
        let now = date(2025, 1, 8, 12, 0, calendar: calendar)
        let week = ProgressPresentation.weekInterval(containing: now, calendar: calendar)
        let completedID = UUID()
        let idleCompletedID = UUID()
        let archivedID = UUID()
        let plans = [
            ProgressPlanRecord(id: planA, title: "Spanish", status: .active, taskStatuses: [.pending]),
            ProgressPlanRecord(id: completedID, title: "Finished book", status: .completed, taskStatuses: [.completed]),
            ProgressPlanRecord(id: idleCompletedID, title: "Old goal", status: .completed, taskStatuses: [.completed]),
            ProgressPlanRecord(id: archivedID, title: "Archived", status: .archived, taskStatuses: [.pending]),
        ]
        let sessions = [
            session(
                id: sessionA,
                startedAt: date(2025, 1, 7, 10, 0, calendar: calendar),
                elapsedSeconds: 300,
                outcome: .completed,
                planID: completedID
            ),
            session(
                id: sessionB,
                startedAt: date(2025, 1, 7, 11, 0, calendar: calendar),
                elapsedSeconds: 120,
                outcome: .completed,
                planID: archivedID
            ),
        ]

        let rows = ProgressPresentation.planRows(plans: plans, sessions: sessions, week: week)
        #expect(rows.map(\.id) == [planA, completedID])
        #expect(rows[0].completedSessionCount == 0)
        #expect(rows[0].focusedSeconds == 0)
        #expect(rows[1].isCompletedPlan)
        #expect(rows[1].completedSessionCount == 1)
        #expect(!rows.contains { $0.id == archivedID || $0.id == idleCompletedID })
    }

    @Test
    func historyKeepsNewestFirstAndQuickFocusTitle() {
        let locale = Locale(identifier: "en_US_POSIX")
        let calendar = gregorianCalendar(firstWeekday: 1)
        let newer = session(
            id: sessionA,
            startedAt: date(2025, 1, 8, 12, 0, calendar: calendar),
            elapsedSeconds: 60,
            outcome: .completed,
            taskTitle: "Practice hola"
        )
        let older = session(
            id: sessionB,
            startedAt: date(2025, 1, 7, 12, 0, calendar: calendar),
            elapsedSeconds: 30,
            outcome: .cancelled
        )
        let items = ProgressPresentation.historyItems(sessions: [newer, older], locale: locale)
        #expect(items.map(\.id) == [sessionA, sessionB])
        #expect(items[0].title == "Practice hola")
        #expect(items[1].title == ProgressCopy.quickFocusTitle)
        #expect(items[1].detail.contains("broken"))
    }

    @Test
    func exposesProgressAccessibilityIdentifiers() {
        #expect(ProgressAccessibilityIdentifier.weekSummary == "progressWeekSummary")
        #expect(ProgressAccessibilityIdentifier.momentum == "progressMomentum")
        #expect(ProgressAccessibilityIdentifier.planRow == "progressPlanRow")
    }

    private func gregorianCalendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = firstWeekday
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }

    private func session(
        id: UUID,
        startedAt: Date,
        elapsedSeconds: Int,
        outcome: SessionOutcome?,
        taskTitle: String? = nil,
        planID: UUID? = nil
    ) -> ProgressSessionRecord {
        ProgressSessionRecord(
            id: id,
            startedAt: startedAt,
            elapsedSeconds: elapsedSeconds,
            outcome: outcome,
            taskTitle: taskTitle,
            planID: planID
        )
    }
}
