import SwiftUI

enum ProgressChartPalette {
    static func weekdayColor(index: Int) -> Color {
        let colors = [
            Color(red: 0.98, green: 0.80, blue: 0.22),
            Color(red: 0.95, green: 0.62, blue: 0.16),
            Color(red: 0.90, green: 0.42, blue: 0.08),
            Color(red: 0.12, green: 0.56, blue: 0.47),
            Color(red: 0.18, green: 0.40, blue: 0.48),
            Color(red: 0.45, green: 0.32, blue: 0.90),
            Color(red: 0.96, green: 0.45, blue: 0.28),
        ]
        return colors[abs(index) % colors.count]
    }

    static func timeOfDayColor(id: String) -> Color {
        switch id {
        case ProgressTimeOfDay.morning.rawValue:
            Color(red: 0.98, green: 0.80, blue: 0.22)
        case ProgressTimeOfDay.afternoon.rawValue:
            Color(red: 0.12, green: 0.56, blue: 0.47)
        case ProgressTimeOfDay.evening.rawValue:
            Color(red: 0.90, green: 0.42, blue: 0.08)
        case ProgressTimeOfDay.night.rawValue:
            Color(red: 0.29, green: 0.40, blue: 0.96)
        default:
            Color.focusAccent
        }
    }
}

enum ProgressChartKind {
    case weekday
    case timeOfDay
}
