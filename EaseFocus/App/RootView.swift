import SwiftData
import SwiftUI

private enum RootTab: Hashable, CaseIterable, Identifiable {
    case pomodoro
    case statistics
    case taskAdviser

    var id: Self { self }

    var title: LocalizedCopy {
        switch self {
        case .pomodoro:
            AppCopy.pomodoro
        case .statistics:
            AppCopy.statistics
        case .taskAdviser:
            AppCopy.taskAdviser
        }
    }

    var systemImage: String {
        switch self {
        case .pomodoro:
            "timer"
        case .statistics:
            "chart.bar"
        case .taskAdviser:
            "lightbulb"
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(FocusTimerController.self) private var timer
    @AppStorage(FirstRunOnboarding.completedKey) private var didCompleteOnboarding = false
    @State private var isShowingOnboarding = false
    @State private var selectedTab: RootTab = .pomodoro

    var body: some View {
        VStack(spacing: 0) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            rootTabBarChrome
        }
        .background(Color.focusBackground)
        .environment(timer)
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
            Task {
                QuoteLibraryStore.prepareFromCache()
                await QuoteLibraryStore.refreshFromRemote()
            }
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

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .pomodoro:
            PomodoroListView()
        case .statistics:
            SessionHistoryView()
        case .taskAdviser:
            TaskAdviserView()
        }
    }

    private var rootTabBarChrome: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.focusPrimary.opacity(0.14))
                .frame(height: 1)
            rootTabBar
                .padding(.horizontal, FocusSpacing.medium)
                .padding(.top, FocusSpacing.small + 2)
                .padding(.bottom, FocusSpacing.small + 2)
        }
        .background(Color.focusSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.focusPrimary.opacity(0.06))
                .frame(height: 8)
                .blur(radius: 4)
                .offset(y: -4)
                .allowsHitTesting(false)
        }
    }

    private var rootTabBar: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { tab in
                rootTabButton(tab)
            }
        }
        .padding(4)
        .background(Color.focusBackground.opacity(0.72), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.focusPrimary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("rootTabBar")
    }

    private func rootTabButton(_ tab: RootTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            guard selectedTab != tab else {
                return
            }
            if reduceMotion {
                selectedTab = tab
            } else {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    selectedTab = tab
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: tab.systemImage)
                    .font(.body.weight(.semibold))
                Text(tab.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.white : Color.focusPrimary.opacity(0.72))
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background {
                if isSelected {
                    Capsule()
                        .fill(FocusChrome.gradient(for: .accent))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("rootTab-\(tab.id)")
    }
}

#Preview {
    RootView()
        .environment(FocusTimerController())
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
        .environment(\.planRefinementClient, PreviewPlanRefinementClient())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
