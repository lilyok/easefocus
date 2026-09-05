import SwiftData
import SwiftUI

struct SessionHistoryView: View {
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var sessions: [FocusSession]
    @Query(sort: \GoalPlan.updatedAt, order: .reverse) private var plans: [GoalPlan]
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sessionRecords: [ProgressSessionRecord] {
        sessions.map { session in
            ProgressSessionRecord(
                id: session.id,
                startedAt: session.startedAt,
                elapsedSeconds: session.elapsedSeconds,
                outcome: session.outcome,
                taskTitle: session.task?.title,
                planID: session.task?.plan?.id
            )
        }
    }

    private var planRecords: [ProgressPlanRecord] {
        plans.map { plan in
            ProgressPlanRecord(
                id: plan.id,
                title: plan.title,
                status: plan.status,
                taskStatuses: plan.tasks.map(\.status)
            )
        }
    }

    private var week: ProgressWeekInterval {
        ProgressPresentation.weekInterval(containing: .now, calendar: calendar)
    }

    private var weekSummary: ProgressCountSummary {
        ProgressPresentation.summary(sessions: sessionRecords, in: week)
    }

    private var todaySummary: ProgressCountSummary {
        ProgressPresentation.todaySummary(sessions: sessionRecords, now: .now, calendar: calendar)
    }

    private var momentumDays: [ProgressMomentumDay] {
        ProgressPresentation.momentumDays(sessions: sessionRecords, now: .now, calendar: calendar)
    }

    private var planRows: [ProgressPlanRow] {
        ProgressPresentation.planRows(plans: planRecords, sessions: sessionRecords, week: week)
    }

    private var historyItems: [ProgressHistoryItem] {
        ProgressPresentation.historyItems(sessions: sessionRecords, locale: locale)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty && planRows.isEmpty {
                    ContentUnavailableView {
                        Label(ProgressCopy.emptyTitle, systemImage: "chart.line.uptrend.xyaxis")
                    } description: {
                        Text(ProgressCopy.emptyDescription)
                    }
                } else {
                    progressList
                }
            }
            .background(Color.focusBackground)
            .navigationTitle(ProgressCopy.navigationTitle)
            .navigationDestination(for: GoalPlan.self) { plan in
                PlanDetailView(plan: plan)
            }
            .transaction { transaction in
                if reduceMotion {
                    transaction.disablesAnimations = true
                }
            }
        }
    }

    private var progressList: some View {
        List {
            Section(ProgressCopy.thisWeek) {
                VStack(alignment: .leading, spacing: FocusSpacing.small) {
                    Text(ProgressPresentation.weekTitle(week: week, calendar: calendar, locale: locale))
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                    Text(ProgressPresentation.countLine(weekSummary))
                        .font(FocusTypography.body)
                        .foregroundStyle(Color.focusPrimary)
                        .accessibilityIdentifier(ProgressAccessibilityIdentifier.weekSummary)
                    momentumRow
                }
                .padding(.vertical, 4)
            }

            if !planRows.isEmpty {
                Section(ProgressCopy.plans) {
                    ForEach(planRows) { row in
                        if let plan = plans.first(where: { $0.id == row.id }) {
                            NavigationLink(value: plan) {
                                planRowView(row)
                            }
                            .accessibilityIdentifier(ProgressAccessibilityIdentifier.planRow)
                        }
                    }
                }
            }

            if sessions.isEmpty {
                Section {
                    Text(ProgressCopy.emptyTitle)
                        .font(FocusTypography.body)
                    Text(ProgressCopy.emptyDescription)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(ProgressCopy.today) {
                    Text(ProgressPresentation.countLine(todaySummary))
                        .font(FocusTypography.body)
                }
                Section(ProgressCopy.history) {
                    ForEach(historyItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(FocusTypography.body)
                                .foregroundStyle(Color.focusPrimary)
                            Text(item.detail)
                                .font(FocusTypography.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var momentumRow: some View {
        HStack(spacing: FocusSpacing.small) {
            ForEach(momentumDays) { day in
                VStack(spacing: 4) {
                    Text(day.weekdaySymbol)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                    Image(systemName: day.hasCompletedFocus ? "checkmark.circle.fill" : "circle")
                        .font(FocusTypography.body)
                        .foregroundStyle(momentumColor(day))
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(ProgressPresentation.momentumAccessibilityLabel(day))
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ProgressAccessibilityIdentifier.momentum)
    }

    private func planRowView(_ row: ProgressPlanRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: FocusSpacing.small) {
                Text(row.title)
                    .font(FocusTypography.body)
                    .foregroundStyle(Color.focusPrimary)
                if row.isCompletedPlan {
                    Text(ProgressCopy.completedPlan)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Text(ProgressPresentation.planTaskLine(open: row.openTaskCount, done: row.doneTaskCount))
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
            Text(ProgressPresentation.planWeekLine(
                completed: row.completedSessionCount,
                focusedSeconds: row.focusedSeconds
            ))
            .font(FocusTypography.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func momentumColor(_ day: ProgressMomentumDay) -> Color {
        if day.hasCompletedFocus {
            return Color.focusSuccess
        }
        if day.isToday {
            return Color.focusAccent
        }
        return Color.secondary
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
