import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct StatisticsShareItem: Transferable, Sendable {
    var pngData: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.pngData
        }
        .suggestedFileName("Pomodoro-Planner-week.png")
    }
}

enum StatisticsShareRendering {
    static let cardWidth: CGFloat = 720

    @MainActor
    static func pngData(
        weekTitle: String,
        summary: ProgressCountSummary,
        weekdayBars: [ProgressUsageBar],
        timeOfDayBars: [ProgressUsageBar],
        peakDay: String?,
        peakTime: String?,
        locale: Locale
    ) -> Data? {
        let card = StatisticsShareCard(
            weekTitle: weekTitle,
            summary: summary,
            weekdayBars: weekdayBars,
            timeOfDayBars: timeOfDayBars,
            peakDay: peakDay,
            peakTime: peakTime
        )
        .environment(\.locale, locale)
        .environment(\.colorScheme, .light)
        .frame(width: cardWidth)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: cardWidth, height: nil)
        guard let cgImage = renderer.cgImage else {
            return nil
        }
        return pngData(from: cgImage)
    }

    @MainActor
    private static func pngData(from cgImage: CGImage) -> Data? {
        #if os(macOS)
        let representation = NSBitmapImageRep(cgImage: cgImage)
        return representation.representation(using: .png, properties: [:])
        #else
        UIImage(cgImage: cgImage).pngData()
        #endif
    }
}

struct StatisticsShareCard: View {
    let weekTitle: String
    let summary: ProgressCountSummary
    let weekdayBars: [ProgressUsageBar]
    let timeOfDayBars: [ProgressUsageBar]
    let peakDay: String?
    let peakTime: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.large) {
            HStack(spacing: FocusSpacing.medium) {
                EaseFocusMark(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppCopy.appName)
                        .font(FocusTypography.title)
                        .foregroundStyle(Color.focusPrimary)
                    Text(ProgressCopy.thisWeek)
                        .font(FocusTypography.footnote.weight(.semibold))
                        .foregroundStyle(FocusChrome.accentEnd)
                }
                Spacer(minLength: 0)
            }
            Text(weekTitle)
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
            ProgressWeekStatTiles(summary: summary)
            chartBlock(title: ProgressCopy.byDay, bars: weekdayBars, kind: .weekday)
            chartBlock(title: ProgressCopy.byTimeOfDay, bars: timeOfDayBars, kind: .timeOfDay)
            if let peakDay {
                Text(ProgressCopy.mostProductiveDay(peakDay))
                    .font(FocusTypography.footnote)
                    .foregroundStyle(Color.focusPrimary)
            }
            if let peakTime {
                Text(ProgressCopy.mostProductiveTime(peakTime))
                    .font(FocusTypography.footnote)
                    .foregroundStyle(Color.focusPrimary)
            }
        }
        .padding(FocusSpacing.large)
        .frame(width: StatisticsShareRendering.cardWidth, alignment: .leading)
        .background(Color.focusBackground)
    }

    private func chartBlock(
        title: LocalizedCopy,
        bars: [ProgressUsageBar],
        kind: ProgressChartKind
    ) -> some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            Text(title)
                .font(FocusTypography.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            ProgressUsageChart(bars: bars, kind: kind, accessibilityIdentifier: "")
        }
        .padding(FocusSpacing.medium)
        .background(Color.focusSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ProgressWeekStatTiles: View {
    let summary: ProgressCountSummary

    var body: some View {
        HStack(spacing: FocusSpacing.small) {
            tile(
                value: "\(summary.completedCount)",
                caption: ProgressCopy.completedCount,
                fill: FocusChrome.accentStart
            )
            tile(
                value: "\(summary.brokenCount)",
                caption: ProgressCopy.brokenCount,
                fill: FocusChrome.destructiveStart
            )
            tile(
                value: FocusDurationFormat.clock(summary.focusedSeconds),
                caption: ProgressCopy.focusedTime,
                fill: Color(red: 0.12, green: 0.56, blue: 0.47)
            )
        }
    }

    private func tile(value: String, caption: LocalizedCopy, fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(FocusTypography.title)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(caption)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(FocusSpacing.small)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
