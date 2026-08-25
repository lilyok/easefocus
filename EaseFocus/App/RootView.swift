import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var timer = FocusTimerController()
    @State private var isShowingTimer = false

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                TodayView()
            }
            Tab("Plans", systemImage: "list.bullet.rectangle") {
                PlansListView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                SessionHistoryView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
        .tint(Color.focusAccent)
        .environment(timer)
        .safeAreaInset(edge: .bottom) {
            if timer.engine.isActive {
                CompactTimerBar {
                    isShowingTimer = true
                }
            }
        }
        .sheet(isPresented: $isShowingTimer) {
            NavigationStack {
                TimerView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isShowingTimer = false }
                        }
                    }
            }
            .environment(timer)
        }
        .onAppear {
            timer.attach(modelContext: modelContext)
        }
        .task {
            await timer.requestNotificationPermission()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            timer.tick(now: date)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
