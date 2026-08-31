import SwiftData
import SwiftUI

struct PlanDetailView: View {
    @Bindable var plan: GoalPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusTimerController.self) private var timer
    @State private var newTaskTitle = ""
    @State private var newTaskEstimate = 1
    @State private var taskPendingRemoval: PlanTask?
    @State private var saveErrorMessage: String?
    @State private var isSaveAlertPresented = false
    @State private var pendingSaveRetry: (() -> Void)?

    var body: some View {
        List {
            Section {
                TextField("Title", text: $plan.title)
                TextField("Details", text: Binding(
                    get: { plan.details ?? "" },
                    set: { plan.details = $0.nilIfEmpty }
                ), axis: .vertical)
            }
            Section {
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
                    .taskRowActions(
                        canStart: timer.engine.canStartFocus && task.status != .completed,
                        onStart: {
                            startFocus(on: task)
                        },
                        onRemove: { taskPendingRemoval = task }
                    )
                }
                .onMove(perform: moveTasks)
                VStack(alignment: .leading, spacing: FocusSpacing.small) {
                    HStack {
                        TextField("New task", text: $newTaskTitle)
                        Button("Add") {
                            addTask()
                        }
                        .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Stepper(value: $newTaskEstimate, in: DraftPlanValidator.pomodoroRange) {
                        Text("\(newTaskEstimate) estimated sessions")
                            .font(FocusTypography.footnote)
                    }
                }
            } header: {
                Text("Tasks")
            } footer: {
                Text("Use the arrow buttons to reorder saved tasks. Search queries are saved for external search in a future update.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.focusBackground)
        .navigationTitle("Plan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Plan actions") {
                    Button("Archive") {
                        plan.status = .archived
                        plan.updatedAt = .now
                    }
                    Button("Mark completed") {
                        plan.status = .completed
                        plan.updatedAt = .now
                    }
                }
            }
        }
        .onChange(of: plan.title) {
            plan.updatedAt = .now
        }
        .confirmationDialog(
            "Remove this task?",
            isPresented: Binding(
                get: { taskPendingRemoval != nil },
                set: { if !$0 { taskPendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: taskPendingRemoval
        ) { task in
            Button("Remove", role: .destructive) {
                remove(task)
                taskPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { task in
            Text("“\(task.title)” will be deleted from the plan.")
        }
        .persistenceSaveAlert(
            isPresented: $isSaveAlertPresented,
            message: saveErrorMessage,
            onRetry: { pendingSaveRetry?() },
            onDiscard: discardFailedSave
        )
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
                    Text("\(task.estimatedPomodoros) estimated sessions")
                        .font(FocusTypography.footnote)
                }
            }
            HStack {
                Text("Order")
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
