import SwiftData
import SwiftUI

struct PlanDetailView: View {
    @Bindable var plan: GoalPlan
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planRefinementClient) private var planRefinementClient
    @Environment(FocusTimerController.self) private var timer
    @State private var newTaskTitle = ""
    @State private var newTaskEstimate = 1
    @State private var taskPendingRemoval: PlanTask?
    @State private var saveErrorMessage: String?
    @State private var isSaveAlertPresented = false
    @State private var pendingSaveRetry: (() -> Void)?
    @State private var isRefiningPlan = false
    @State private var historyCoordinator = PlanHistoryCoordinator()

    private var showsRefineAction: Bool {
        PlanRefinementPresentation.showsRefineAction(
            planStatus: plan.status,
            availability: planRefinementClient.currentAvailability(locale: locale)
        )
    }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: FocusSpacing.small) {
                TextField(PlanDetailCopy.title, text: $plan.title)
                    .focusField()
                TextField(PlanDetailCopy.details, text: Binding(
                    get: { plan.details ?? "" },
                    set: { plan.details = $0.nilIfEmpty }
                ), axis: .vertical)
                    .focusField()
            }
            .focusCard()
            .focusListRow()

            FocusSectionHeader(title: PlanDetailCopy.tasks)
                .focusListRow()
            ForEach(plan.orderedTasks) { task in
                let index = plan.orderedTasks.firstIndex(where: { $0.id == task.id }) ?? 0
                EditableTaskRow(
                    task: task,
                    isStartEnabled: timer.engine.canStartFocus,
                    canMoveUp: index > 0,
                    canMoveDown: index < plan.orderedTasks.count - 1,
                    onMarkCompleted: {
                        toggleCompletion(task)
                    },
                    onStart: {
                        startFocus(on: task)
                    },
                    onMoveUp: { moveTask(task, direction: .up) },
                    onMoveDown: { moveTask(task, direction: .down) }
                )
                .id(task.id)
                .focusCard()
                .focusListRow()
                .swipeToRemove {
                    taskPendingRemoval = task
                }
                .taskRowActions(
                    canStart: timer.engine.canStartFocus && task.status != .completed,
                    onStart: {
                        startFocus(on: task)
                    },
                    onRemove: { taskPendingRemoval = task }
                )
            }

            VStack(alignment: .leading, spacing: FocusSpacing.small) {
                HStack {
                    TextField(PlanDetailCopy.newTask, text: $newTaskTitle)
                        .focusField()
                    FocusCapsuleButton(
                        title: PlanDetailCopy.add,
                        enabled: !newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        action: addTask
                    )
                    .frame(maxWidth: 120)
                }
                Stepper(value: $newTaskEstimate, in: DraftPlanValidator.pomodoroRange) {
                    Text(TaskCopy.estimatedSessions(newTaskEstimate))
                        .font(FocusTypography.footnote)
                }
                Text(PlanEditorCopy.reorderFooter)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }
            .focusCard()
            .focusListRow()

            if PlanHistoryPresentation.showsHistory(revisionCount: plan.revisions.count) {
                NavigationLink {
                    PlanHistoryView(plan: plan)
                } label: {
                    Text(PlanHistoryCopy.historyTitle)
                        .font(FocusTypography.body)
                        .foregroundStyle(Color.focusPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .focusCard()
                .focusListRow()
                .accessibilityIdentifier(PlanHistoryAccessibilityIdentifier.history)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .focusScreen()
        .navigationTitle(PlanDetailCopy.navigationTitle)
        .toolbar {
            if showsRefineAction {
                ToolbarItem(placement: .primaryAction) {
                    Button(PlanRefinementCopy.refineAction) {
                        isRefiningPlan = true
                    }
                    .accessibilityIdentifier(PlanRefinementAccessibilityIdentifier.refineAction)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(PlanDetailCopy.archive) {
                        plan.status = .archived
                        plan.updatedAt = .now
                    }
                    Button(PlanDetailCopy.markCompleted) {
                        plan.status = .completed
                        plan.updatedAt = .now
                    }
                    Button(PlanHistoryCopy.startOverAction, role: .destructive) {
                        historyCoordinator.requestStartOver(
                            isSessionRunningOnPlan: PlanHistorySession.isRunning(on: plan, timer: timer)
                        )
                    }
                    .disabled(!historyCoordinator.canStartOver(
                        isSessionRunningOnPlan: PlanHistorySession.isRunning(on: plan, timer: timer)
                    ))
                    .accessibilityIdentifier(PlanHistoryAccessibilityIdentifier.startOver)
                } label: {
                    Text(PlanDetailCopy.planActions)
                }
            }
        }
        .onChange(of: plan.title) {
            plan.updatedAt = .now
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
                taskPendingRemoval = nil
            }
            Button(AppCopy.cancel, role: .cancel) {}
        } message: { task in
            Text(TaskCopy.deleteMessage(taskTitle: task.title))
        }
        .confirmationDialog(
            Text(PlanHistoryCopy.startOverConfirmTitle),
            isPresented: $historyCoordinator.isStartOverConfirmPresented,
            titleVisibility: .visible
        ) {
            Button(PlanHistoryCopy.confirmStartOver, role: .destructive) {
                historyCoordinator.confirmStartOver(
                    plan: plan,
                    context: modelContext,
                    isSessionRunningOnPlan: PlanHistorySession.isRunning(on: plan, timer: timer)
                )
            }
            .accessibilityIdentifier(PlanHistoryAccessibilityIdentifier.confirmStartOver)
            Button(PlanHistoryCopy.cancelStartOver, role: .cancel) {
            }
            .accessibilityIdentifier(PlanHistoryAccessibilityIdentifier.cancelStartOver)
        } message: {
            Text(PlanHistoryCopy.startOverConfirmMessage)
        }
        .persistenceSaveAlert(
            isPresented: $isSaveAlertPresented,
            message: saveErrorMessage,
            onRetry: { pendingSaveRetry?() },
            onDiscard: discardFailedSave
        )
        .persistenceSaveAlert(
            isPresented: $historyCoordinator.isSaveAlertPresented,
            message: historyCoordinator.saveErrorMessage,
            onRetry: { historyCoordinator.retrySave() },
            onDiscard: { historyCoordinator.discardFailedSave() }
        )
        .sheet(isPresented: $isRefiningPlan) {
            RefinePlanView(plan: plan)
        }
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return
        }
        let estimate = newTaskEstimate
        commit(
            apply: {
                let task = PlanTask(
                    title: title,
                    position: plan.tasks.count,
                    estimatedPomodoros: estimate
                )
                task.plan = plan
                plan.tasks.append(task)
                plan.updatedAt = .now
            },
            onSuccess: {
                newTaskTitle = ""
                newTaskEstimate = 1
            }
        )
    }

    private func toggleCompletion(_ task: PlanTask) {
        commit(
            apply: {
                task.toggleCompletion()
                plan.updatedAt = .now
            }
        )
    }

    private func startFocus(on task: PlanTask) {
        commit(
            apply: {
                plan.moveTaskToFront(task)
            },
            onSuccess: {
                timer.startFocus(task: task)
            }
        )
    }

    private func remove(_ task: PlanTask) {
        commit(
            apply: {
                plan.updatedAt = .now
                modelContext.delete(task)
            }
        )
    }

    private func moveTasks(from offsets: IndexSet, to destination: Int) {
        commit(
            apply: {
                var ordered = plan.orderedTasks
                ordered.move(fromOffsets: offsets, toOffset: destination)
                for (index, task) in ordered.enumerated() {
                    task.position = index
                    task.updatedAt = .now
                }
                plan.updatedAt = .now
            }
        )
    }

    private func moveTask(_ task: PlanTask, direction: TaskMoveDirection) {
        commit(
            apply: {
                plan.moveTask(task, direction: direction)
            }
        )
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

private struct EditableTaskRow: View {
    @Bindable var task: PlanTask
    var isStartEnabled: Bool
    var canMoveUp: Bool
    var canMoveDown: Bool
    var onMarkCompleted: () -> Void
    var onStart: () -> Void
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            TaskRowView(
                task: task,
                onMarkCompleted: onMarkCompleted,
                onStart: onStart,
                isStartEnabled: isStartEnabled
            )
            if task.status != .completed {
                Stepper(value: $task.estimatedPomodoros, in: DraftPlanValidator.pomodoroRange) {
                    Text(TaskCopy.estimatedSessions(task.estimatedPomodoros))
                        .font(FocusTypography.footnote)
                }
            }
            HStack {
                Text(PlanDetailCopy.order)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                TaskReorderControls(
                    canMoveUp: canMoveUp,
                    canMoveDown: canMoveDown,
                    onMoveUp: onMoveUp,
                    onMoveDown: onMoveDown
                )
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
