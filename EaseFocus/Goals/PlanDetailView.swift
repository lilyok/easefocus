import SwiftData
import SwiftUI

struct PlanDetailView: View {
    @Bindable var plan: GoalPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusTimerController.self) private var timer
    @State private var newTaskTitle = ""
    @State private var newTaskEstimate = 1

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
                    EditableTaskRow(
                        task: task,
                        isStartEnabled: timer.engine.canStartFocus
                    ) {
                        timer.startFocus(task: task)
                    }
                    .swipeActions(edge: .trailing) {
                        if task.status != .completed {
                            Button("Complete") {
                                task.markCompleted()
                                plan.updatedAt = .now
                            }
                            .tint(Color.focusSuccess)
                        }
                    }
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
    }
}

private struct EditableTaskRow: View {
    @Bindable var task: PlanTask
    var isStartEnabled: Bool
    var onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            TaskRowView(task: task, onStart: onStart, isStartEnabled: isStartEnabled)
            if task.status != .completed {
                Stepper(value: $task.estimatedPomodoros, in: DraftPlanValidator.pomodoroRange) {
                    Text("\(task.estimatedPomodoros) estimated sessions")
                        .font(FocusTypography.footnote)
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
