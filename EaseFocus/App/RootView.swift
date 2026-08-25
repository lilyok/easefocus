import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                TodayView()
            }
            Tab("Plans", systemImage: "list.bullet.rectangle") {
                PlansPlaceholderView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressPlaceholderView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
        .tint(Color.focusAccent)
    }
}

#Preview {
    RootView()
        .modelContainer(for: FocusItem.self, inMemory: true)
}
