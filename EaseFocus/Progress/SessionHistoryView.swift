import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SessionHistoryView: View {
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var sessions: [FocusSession]
    @Query(sort: \GoalPlan.updatedAt, order: .reverse) private var plans: [GoalPlan]
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sharePNG: Data?

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

    private var planRows: [ProgressPlanRow] {
        ProgressPresentation.planRows(plans: planRecords, sessions: sessionRecords, week: week)
    }

    private var historyItems: [ProgressHistoryItem] {
        ProgressPresentation.historyItems(sessions: sessionRecords, locale: locale)
    }

    var body: some View {
        NavigationStack {
            Group {
                if ProgressPresentation.showsFullEmptyState(
                    sessionCount: sessions.count,
                    planRowCount: planRows.count
                ) {
                    FocusEmptyState(
                        title: ProgressCopy.emptyTitle,
                        description: ProgressCopy.emptyDescription
                    )
                } else {
                    progressList
                }
            }
            .background(Color.focusBackground)
            .focusScreen()
            .navigationTitle(ProgressCopy.navigationTitle)
            .navigationDestination(for: GoalPlan.self) { plan in
                PlanDetailView(plan: plan)
            }
            .transaction { transaction in
                if reduceMotion {
                    transaction.disablesAnimations = true
                }
            }
            .task(id: shareFingerprint) {
                await renderShareImage()
            }
        }
    }

    private var weekdayBars: [ProgressUsageBar] {
        ProgressPresentation.weekdayUsage(
            sessions: sessionRecords,
            now: .now,
            calendar: calendar
        )
    }

    private var timeOfDayBars: [ProgressUsageBar] {
        ProgressPresentation.timeOfDayUsage(
            sessions: sessionRecords,
            in: week,
            calendar: calendar
        ).map { bar in
            var localized = bar
            if let bucket = ProgressTimeOfDay(rawValue: bar.id) {
                let title = bucket.title.localized(locale)
                localized.label = title
                localized.insightLabel = title
            }
            return localized
        }
    }

    private var weekTitle: String {
        ProgressPresentation.weekTitle(week: week, calendar: calendar, locale: locale)
    }

    private var weekShareText: String {
        var lines = [
            ProgressCopy.thisWeek.localized(locale),
            weekTitle,
            ProgressPresentation.countLine(weekSummary, locale: locale),
        ]
        if let weekday = ProgressPresentation.peakUsageLabel(in: weekdayBars) {
            lines.append(ProgressCopy.mostProductiveDay(weekday).localized(locale))
        }
        if let timeOfDay = ProgressPresentation.peakUsageLabel(in: timeOfDayBars) {
            lines.append(ProgressCopy.mostProductiveTime(timeOfDay).localized(locale))
        }
        return lines.joined(separator: "\n")
    }

    private var shareFingerprint: String {
        weekdayBars.map { "\($0.id):\($0.focusedSeconds)" }.joined(separator: "|")
            + "|"
            + timeOfDayBars.map { "\($0.id):\($0.focusedSeconds)" }.joined(separator: "|")
            + "|\(weekSummary.completedCount)-\(weekSummary.brokenCount)-\(weekSummary.focusedSeconds)"
    }

    private var progressList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: FocusSpacing.medium) {
                weekCard

                if !planRows.isEmpty {
                    Text(ProgressCopy.plans)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    ForEach(planRows) { row in
                        if let plan = plans.first(where: { $0.id == row.id }) {
                            NavigationLink(value: plan) {
                                planRowView(row)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(ProgressAccessibilityIdentifier.planRow(for: row.id))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: FocusSpacing.small) {
                    Text(ProgressCopy.today)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                    ProgressWeekStatTiles(summary: todaySummary)
                    Text(ProgressPresentation.countLine(todaySummary, locale: locale))
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("progressTodaySummary")
                }
                .focusCard()

                VStack(alignment: .leading, spacing: FocusSpacing.small) {
                    Text(ProgressCopy.history)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(historyItems) { item in
                        HStack(alignment: .top, spacing: FocusSpacing.small) {
                            Circle()
                                .fill(FocusChrome.gradient(for: .accent))
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
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
                .focusCard()
            }
            .padding(.horizontal, FocusSpacing.medium)
            .padding(.vertical, FocusSpacing.small)
        }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ProgressCopy.thisWeek)
                        .font(FocusTypography.title)
                        .foregroundStyle(Color.focusPrimary)
                    Text(weekTitle)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: FocusSpacing.small)
                shareControl
            }
            ProgressWeekStatTiles(summary: weekSummary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    ProgressPresentation.countLine(weekSummary, locale: locale)
                )
                .accessibilityIdentifier(ProgressAccessibilityIdentifier.weekSummary)
            chartBlock(
                title: ProgressCopy.byDay,
                bars: weekdayBars,
                kind: .weekday,
                identifier: ProgressAccessibilityIdentifier.momentum
            )
            if let weekday = ProgressPresentation.peakUsageLabel(in: weekdayBars) {
                insightRow(
                    systemImage: "sun.max.fill",
                    text: ProgressCopy.mostProductiveDay(weekday)
                )
            }
            chartBlock(
                title: ProgressCopy.byTimeOfDay,
                bars: timeOfDayBars,
                kind: .timeOfDay,
                identifier: "progressTimeOfDay"
            )
            if let timeOfDay = ProgressPresentation.peakUsageLabel(in: timeOfDayBars) {
                insightRow(
                    systemImage: "clock.fill",
                    text: ProgressCopy.mostProductiveTime(timeOfDay)
                )
            }
        }
        .focusCard()
    }

    @ViewBuilder
    private var shareControl: some View {
        if let sharePNG, !sharePNG.isEmpty {
            ShareLink(
                item: StatisticsShareItem(pngData: sharePNG),
                subject: Text(AppCopy.appName),
                message: Text(weekShareText),
                preview: SharePreview(
                    Text(ProgressCopy.thisWeek),
                    image: sharePreviewImage(sharePNG)
                )
            ) {
                Text(ProgressCopy.share)
                    .focusCapsuleFill()
            }
            .buttonStyle(FocusCapsuleButtonStyle())
            .frame(minWidth: 108)
            .accessibilityIdentifier("shareStatistics")
        } else {
            ShareLink(item: weekShareText) {
                Text(ProgressCopy.share)
                    .focusCapsuleFill()
            }
            .buttonStyle(FocusCapsuleButtonStyle())
            .frame(minWidth: 108)
            .accessibilityIdentifier("shareStatistics")
        }
    }

    private func sharePreviewImage(_ data: Data) -> Image {
        #if os(macOS)
        Image(nsImage: NSImage(data: data) ?? NSImage())
        #else
        Image(uiImage: UIImage(data: data) ?? UIImage())
        #endif
    }

    private func chartBlock(
        title: LocalizedCopy,
        bars: [ProgressUsageBar],
        kind: ProgressChartKind,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            Text(title)
                .font(FocusTypography.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            ProgressUsageChart(
                bars: bars,
                kind: kind,
                accessibilityIdentifier: identifier
            )
        }
        .padding(FocusSpacing.small)
        .background(
            Color.focusBackground.opacity(0.65),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func insightRow(systemImage: String, text: LocalizedCopy) -> some View {
        HStack(alignment: .top, spacing: FocusSpacing.small) {
            Image(systemName: systemImage)
                .foregroundStyle(FocusChrome.gradient(for: .accent))
            Text(text)
                .font(FocusTypography.footnote)
                .foregroundStyle(Color.focusPrimary)
        }
    }

    @MainActor
    private func renderShareImage() async {
        let png = StatisticsShareRendering.pngData(
            weekTitle: weekTitle,
            summary: weekSummary,
            weekdayBars: weekdayBars,
            timeOfDayBars: timeOfDayBars,
            peakDay: ProgressPresentation.peakUsageLabel(in: weekdayBars),
            peakTime: ProgressPresentation.peakUsageLabel(in: timeOfDayBars),
            locale: locale
        )
        sharePNG = png
    }

    private func planRowView(_ row: ProgressPlanRow) -> some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            FocusPlanRowContent(
                title: row.title,
                openCount: row.openTaskCount,
                doneCount: row.doneTaskCount,
                showsCompletedBadge: row.isCompletedPlan
            )
            Text(ProgressPresentation.planWeekLine(
                completed: row.completedSessionCount,
                focusedSeconds: row.focusedSeconds,
                locale: locale
            ))
            .font(FocusTypography.footnote)
            .foregroundStyle(.secondary)
        }
        .focusCard()
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
