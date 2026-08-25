import SwiftData
import SwiftUI

struct PlanDetailView: View {
    @Bindable var plan: GoalPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusTimerController.self) private var timer
    @State private var newTaskTitle = ""

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
                    TaskRowView(task: task) {
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
                HStack {
                    TextField("New task", text: $newTaskTitle)
                    Button("Add") {
                        addTask()
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        let task = PlanTask(title: title, position: plan.tasks.count)
        task.plan = plan
        plan.tasks.append(task)
        plan.updatedAt = .now
        newTaskTitle = ""
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
