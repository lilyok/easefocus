import SwiftData
import SwiftUI

struct PlanDetailView: View {
    @Bindable var plan: GoalPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusTimerController.self) private var timer
    @State private var newTaskTitle = ""
    @State private var newTaskEstimate = 1
    @State private var taskPendingRemoval: PlanTask?

    var body: some View {
        List {
            Section {
                TextField("Title", text: $plan.title)
                TextField("Details", text: Binding(
                    get: { plan.details ?? "" },
                    set: { plan.details = $0.nilIfEmpty }
                ), axis: .vertical)
            }
            Section("Tasks") {
                ForEach(plan.orderedTasks) { task in
                    let index = plan.orderedTasks.firstIndex(where: { $0.id == task.id }) ?? 0
                    EditableTaskRow(
                        task: task,
                        isStartEnabled: timer.engine.canStartFocus,
                        canMoveUp: index > 0,
                        canMoveDown: index < plan.orderedTasks.count - 1,
                        onMarkCompleted: {
                            task.toggleCompletion()
                            plan.updatedAt = .now
                            try? modelContext.save()
                        },
                        onStart: {
                            plan.moveTaskToFront(task)
                            timer.startFocus(task: task)
                        },
                        onMoveUp: { moveTask(task, direction: .up) },
                        onMoveDown: { moveTask(task, direction: .down) }
                    )
                    .taskRowActions(
                        canStart: timer.engine.canStartFocus && task.status != .completed,
                        onStart: {
                            plan.moveTaskToFront(task)
                            timer.startFocus(task: task)
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
                modelContext.delete(task)
                plan.updatedAt = .now
                try? modelContext.save()
                taskPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { task in
            Text("“\(task.title)” will be deleted from the plan.")
        }
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return
        }
        let task = PlanTask(
            title: title,
            position: plan.tasks.count,
            estimatedPomodoros: newTaskEstimate
        )
        task.plan = plan
        plan.tasks.append(task)
        plan.updatedAt = .now
        newTaskTitle = ""
        newTaskEstimate = 1
        try? modelContext.save()
    }

    private func moveTasks(from offsets: IndexSet, to destination: Int) {
        var ordered = plan.orderedTasks
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, task) in ordered.enumerated() {
            task.position = index
            task.updatedAt = .now
        }
        plan.updatedAt = .now
        try? modelContext.save()
    }

    private func moveTask(_ task: PlanTask, direction: TaskMoveDirection) {
        plan.moveTask(task, direction: direction)
        try? modelContext.save()
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
