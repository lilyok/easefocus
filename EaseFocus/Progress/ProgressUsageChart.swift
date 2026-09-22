import Charts
import SwiftUI

struct ProgressUsageChart: View {
    let bars: [ProgressUsageBar]
    var kind: ProgressChartKind = .weekday
    var accessibilityIdentifier: String

    var body: some View {
        Chart(Array(bars.enumerated()), id: \.element.id) { index, bar in
            BarMark(
                x: .value(ProgressCopy.thisWeek.english, bar.label),
                y: .value(ProgressCopy.usage.english, bar.focusedSeconds)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        color(for: bar, index: index).opacity(0.72),
                        color(for: bar, index: index),
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .cornerRadius(6)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(FocusTypography.footnote.weight(.semibold))
                            .foregroundStyle(Color.focusPrimary.opacity(0.75))
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.background(Color.focusBackground.opacity(0.6))
        }
        .frame(height: 148)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func color(for bar: ProgressUsageBar, index: Int) -> Color {
        switch kind {
        case .weekday:
            ProgressChartPalette.weekdayColor(index: index)
        case .timeOfDay:
            ProgressChartPalette.timeOfDayColor(id: bar.id)
        }
    }
}
