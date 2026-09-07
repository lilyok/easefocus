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
            Tab {
                TodayView()
            } label: {
                Label(AppCopy.today, systemImage: "sun.max")
            }
            Tab {
                PlansListView()
            } label: {
                Label(AppCopy.plans, systemImage: "list.bullet.rectangle")
            }
            Tab {
                SessionHistoryView()
            } label: {
                Label(AppCopy.progress, systemImage: "chart.line.uptrend.xyaxis")
            }
            Tab {
                SettingsView()
            } label: {
                Label(AppCopy.settings, systemImage: "gear")
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
                            Button(AppCopy.close) { isShowingTimer = false }
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
        }
        .persistenceSaveAlert(
            isPresented: Binding(
                get: { timer.isSaveAlertPresented },
                set: { if !$0 { timer.acknowledgeSaveError() } }
            ),
            message: timer.lastSaveErrorMessage,
            onRetry: { timer.retrySave() },
            onDefer: { timer.acknowledgeSaveError() }
        )
    }
}

#Preview {
    RootView()
        .environment(FocusTimerController())
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
        .environment(\.planRefinementClient, PreviewPlanRefinementClient())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
