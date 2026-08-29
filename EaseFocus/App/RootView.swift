import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FocusTimerController.self) private var timer
    @State private var isShowingTimer = false
    @AppStorage(FirstRunOnboarding.completedKey) private var didCompleteOnboarding = false
    @State private var isShowingOnboarding = false

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
        .sheet(isPresented: $isShowingOnboarding) {
            FirstRunOnboardingView {
                didCompleteOnboarding = true
                isShowingOnboarding = false
            }
            .environment(timer)
            .interactiveDismissDisabled()
        }
        .onAppear {
            timer.attach(modelContext: modelContext)
            Task { await timer.refreshNotificationAccess() }
            if !didCompleteOnboarding {
                isShowingOnboarding = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await timer.refreshNotificationAccess() }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            timer.tick(now: date)
            Task { await timer.refreshNotificationAccess() }
        }
    }
}

#Preview {
    RootView()
        .environment(FocusTimerController())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
