import SwiftData
import SwiftUI

struct PomodoroListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(FocusTimerController.self) private var timer
    @Query(sort: \GoalPlan.updatedAt, order: .reverse)
    private var allPlans: [GoalPlan]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var searchText = ""
    @State private var isShowingSettings = false
    @State private var isShowingQuote = false
    @State private var taskPendingRemoval: PlanTask?
    @State private var saveErrorMessage: String?
    @State private var isSaveAlertPresented = false
    @State private var pendingSaveRetry: (() -> Void)?
    @State private var celebratingTaskID: UUID?
    @State private var pinnedScrollToken = 0
    @State private var scrollTargetID: UUID?
    @State private var highlightedTaskID: UUID?

    private var plans: [GoalPlan] {
        allPlans.filter { $0.status == .active }
    }

    private var visibleTasks: [PlanTask] {
        let tasks = plans.flatMap(\.orderedTasks)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return tasks
        }
        return tasks.filter { PomodoroTaskSearch.matches($0, query: query) }
    }

    private var pinnedTask: PlanTask? {
        guard timer.engine.isActive, let taskID = timer.engine.taskID else {
            return nil
        }
        return allPlans.flatMap(\.orderedTasks).first { $0.id == taskID }
    }

    private var pendingTasks: [PlanTask] {
        visibleTasks.filter { $0.status != .completed && $0.id != pinnedTask?.id }
    }

    private var completedTasks: [PlanTask] {
        visibleTasks.filter { $0.status == .completed && $0.id != pinnedTask?.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: FocusSpacing.small) {
                toolbarRow
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && pendingTasks.isEmpty
                    && completedTasks.isEmpty
                    && pinnedTask == nil {
                    emptyState
                } else {
                    if timer.notificationAccess != .allowed {
                        NotificationAccessNotice(
                            access: timer.notificationAccess,
                            settingsLinkIdentifier: "pomodoroOpenNotificationSettings"
                        )
                        .padding(.horizontal, FocusSpacing.medium)
                    }
                    if let pinnedTask {
                        pomodoroTaskRow(pinnedTask, isPinnedActive: true)
                            .padding(.horizontal, FocusSpacing.medium)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    taskList
                }
            }
            .background(Color.focusBackground)
            .animation(
                reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9),
                value: pinnedTask?.id
            )
            .navigationTitle(PomodoroCopy.navigationTitle)
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
                    .environment(timer)
                    #if os(macOS)
                    .frame(minWidth: 440, minHeight: 560)
                    #endif
            }
            .sheet(isPresented: $isShowingQuote) {
                QuoteView()
                    .environment(\.modelContext, modelContext)
            }
            .confirmationDialog(
                Text(TaskCopy.removeTaskTitle),
                isPresented: Binding(
                    get: { taskPendingRemoval != nil },
                    set: { if !$0 { taskPendingRemoval = nil } }
                ),
                titleVisibility: .visible,
                presenting: taskPendingRemoval
            ) { task in
                Button(TaskCopy.remove, role: .destructive) {
                    remove(task)
                }
                Button(AppCopy.cancel, role: .cancel) {}
            } message: { task in
                Text(TaskCopy.deleteMessage(taskTitle: task.title))
            }
            .persistenceSaveAlert(
                isPresented: $isSaveAlertPresented,
                message: saveErrorMessage,
                onRetry: { pendingSaveRetry?() },
                onDiscard: discardFailedSave
            )
        }
    }

    private var toolbarRow: some View {
        HStack(spacing: FocusSpacing.small) {
            FocusIconButton(
                title: QuoteCopy.quoteOfTheDay,
                systemImage: "quote.bubble",
                identifier: "openQuote"
            ) {
                isShowingQuote = true
            }
            TextField(PomodoroCopy.searchPlaceholder, text: $searchText)
                .textFieldStyle(.roundedBorder)
            FocusIconButton(
                title: AppCopy.settings,
                systemImage: "gearshape",
                identifier: "openSettings"
            ) {
                isShowingSettings = true
            }
            FocusIconButton(
                title: TodayCopy.addTask,
                systemImage: "plus",
                identifier: "addTaskToolbar"
            ) {
                addTask()
            }
        }
        .padding(.horizontal, FocusSpacing.medium)
        .padding(.top, FocusSpacing.small)
    }

    private var emptyState: some View {
        VStack(spacing: FocusSpacing.large) {
            if timer.notificationAccess != .allowed {
                NotificationAccessNotice(
                    access: timer.notificationAccess,
                    settingsLinkIdentifier: "pomodoroOpenNotificationSettings"
                )
                .padding(.horizontal)
            }
            FocusEmptyState(
                title: TodayCopy.readyToFocus,
                description: TodayCopy.emptyDescription
            ) {
                Button(TodayCopy.addTask, systemImage: "plus") {
                    addTask()
                }
                .accessibilityIdentifier("addTask")
                .focusPrimaryActionStyle()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var taskList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: FocusSpacing.medium) {
                    Color.clear
                        .frame(height: 0)
                        .id("taskListTop")
                    ForEach(pendingTasks) { task in
                        pomodoroTaskRow(task)
                            .id(task.id)
                    }
                    ForEach(completedTasks) { task in
                        pomodoroTaskRow(task)
                            .id(task.id)
                    }
                }
                .padding(.horizontal, FocusSpacing.medium)
                .padding(.vertical, FocusSpacing.small)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.86),
                    value: pendingTasks.map(\.id)
                )
                .animation(
                    reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.86),
                    value: completedTasks.map(\.id)
                )
            }
            .onAppear {
                scrollToRequestedTask(using: proxy)
            }
            .onChange(of: scrollTargetID) { _, _ in
                scrollToRequestedTask(using: proxy)
            }
            .onChange(of: pinnedScrollToken) { _, _ in
                scrollListToTop(using: proxy)
            }
        }
    }

    private func scrollListToTop(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                proxy.scrollTo("taskListTop", anchor: .top)
            }
        }
    }

    private func pomodoroTaskRow(
        _ task: PlanTask,
        isPinnedActive: Bool = false
    ) -> some View {
        PomodoroTaskCard(
            task: task,
            canStart: task.status != .completed,
            isPinnedActive: isPinnedActive,
            sessionStatus: isPinnedActive
                ? TimerAccessibilityPresentation.statusTitle(
                    phase: timer.engine.phase,
                    isLongBreak: timer.engine.isLongBreak
                )
                : nil,
            remainingSeconds: isPinnedActive ? timer.engine.remainingSeconds(at: .now) : nil,
            plannedDurationSeconds: isPinnedActive ? timer.engine.plannedDurationSeconds : nil,
            timerActions: isPinnedActive
                ? TimerAccessibilityPresentation.actions(for: timer.engine.phase)
                : [],
            onTimerAction: { timer.perform($0) },
            onStart: { startFocus(on: task) },
            onComplete: { toggleCompletion(task) },
            onTitleCommit: { rename(task, to: $0) },
            onPlanTitleCommit: { retag(task, to: $0) },
            isCelebrating: celebratingTaskID == task.id,
            isNewlyCreated: highlightedTaskID == task.id
        )
        .swipeReveal(actions: swipeActions(for: task))
        .contextMenu {
            if task.status == .completed {
                Button(PomodoroCopy.undoComplete) {
                    toggleCompletion(task)
                }
            } else if !isPinnedActive {
                Button(TaskCopy.startFocus) {
                    startFocus(on: task)
                }
            }
            Button(TaskCopy.remove, role: .destructive) {
                taskPendingRemoval = task
            }
        }
    }

    private func scrollToRequestedTask(using proxy: ScrollViewProxy) {
        guard let scrollTargetID else {
            return
        }
        DispatchQueue.main.async {
            if reduceMotion {
                proxy.scrollTo(scrollTargetID, anchor: .top)
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(scrollTargetID, anchor: .top)
                }
            }
            self.scrollTargetID = nil
        }
    }

    private func addTask() {
        var createdID: UUID?
        commit(
            apply: {
                let plan = TaskInbox.plan(from: allPlans, in: modelContext, locale: locale)
                let task = PlanTask(
                    title: TaskCopy.newTask.localized(locale),
                    position: 0
                )
                plan.insertTaskAtFront(task)
                createdID = task.id
            },
            onSuccess: {
                scrollTargetID = createdID
                highlightedTaskID = createdID
                Task { @MainActor in
                    let delay: Duration = reduceMotion ? .milliseconds(900) : .milliseconds(1400)
                    try? await Task.sleep(for: delay)
                    guard highlightedTaskID == createdID else {
                        return
                    }
                    withAnimation(.easeOut(duration: 0.35)) {
                        highlightedTaskID = nil
                    }
                }
            }
        )
    }

    private func rename(_ task: PlanTask, to title: String) {
        commit(
            apply: {
                task.title = title
                task.updatedAt = .now
                task.plan?.updatedAt = .now
            }
        )
    }

    private func retag(_ task: PlanTask, to title: String) {
        commit(
            apply: {
                TaskInbox.retag(
                    task,
                    to: title,
                    from: allPlans,
                    in: modelContext,
                    locale: locale
                )
            }
        )
    }

    private func swipeActions(for task: PlanTask) -> [SwipeRevealAction] {
        var actions: [SwipeRevealAction] = []
        if task.status == .completed {
            actions.append(
                SwipeRevealAction(
                    id: "undo-\(task.id.uuidString)",
                    title: PomodoroCopy.undoComplete,
                    kind: .accent,
                    handler: { toggleCompletion(task) }
                )
            )
        }
        actions.append(
            SwipeRevealAction(
                id: "remove-\(task.id.uuidString)",
                title: TaskCopy.remove,
                kind: .destructive,
                handler: { taskPendingRemoval = task }
            )
        )
        return actions
    }

    private func toggleCompletion(_ task: PlanTask) {
        let completing = task.status != .completed
        if completing {
            celebratingTaskID = task.id
            TimerCompletionFeedback.play(.completed, playsSound: false)
            let delay: Duration = reduceMotion ? .milliseconds(0) : .milliseconds(520)
            Task { @MainActor in
                try? await Task.sleep(for: delay)
                commit(
                    apply: {
                        task.toggleCompletion()
                        task.plan?.updatedAt = .now
                    }
                )
                celebratingTaskID = nil
            }
        } else {
            commit(
                apply: {
                    task.toggleCompletion()
                    task.plan?.updatedAt = .now
                }
            )
        }
    }

    private func startFocus(on task: PlanTask) {
        commit(
            apply: {
                task.plan?.moveTaskToFront(task)
            },
            onSuccess: {
                timer.startFocus(task: task)
                pinnedScrollToken += 1
            }
        )
    }

    private func remove(_ task: PlanTask) {
        commit(
            apply: {
                task.plan?.updatedAt = .now
                modelContext.delete(task)
            }
        )
        taskPendingRemoval = nil
    }

    private func commit(
        apply: () -> Void,
        onSuccess: @escaping () -> Void = {}
    ) {
        apply()
        savePendingChanges(onSuccess: onSuccess)
    }

    private func savePendingChanges(
        onSuccess: @escaping () -> Void
    ) {
        switch PersistenceSaving.result(of: { try modelContext.save() }) {
        case .saved:
            saveErrorMessage = nil
            isSaveAlertPresented = false
            pendingSaveRetry = nil
            onSuccess()
        case .failed(let message):
            saveErrorMessage = message
            isSaveAlertPresented = true
            pendingSaveRetry = {
                savePendingChanges(onSuccess: onSuccess)
            }
        }
    }

    private func discardFailedSave() {
        modelContext.rollback()
        saveErrorMessage = nil
        isSaveAlertPresented = false
        pendingSaveRetry = nil
    }
}

#Preview {
    PomodoroListView()
        .environment(FocusTimerController())
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
