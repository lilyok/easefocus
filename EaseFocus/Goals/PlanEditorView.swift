import SwiftData
import SwiftUI

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var title = ""
    @State private var details = ""
    @State private var tasks: [DraftTask] = [DraftTask()]

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    TextField("Title", text: $title)
                    TextField("Details", text: $details, axis: .vertical)
                }
                Section("Tasks") {
                    ForEach($tasks) { $task in
                        VStack(alignment: .leading, spacing: FocusSpacing.small) {
                            TextField("Task title", text: $task.title)
                            Stepper(value: $task.estimatedPomodoros, in: DraftPlanValidator.pomodoroRange) {
                                Text("\(task.estimatedPomodoros) estimated sessions")
                                    .font(FocusTypography.footnote)
                            }
                        }
                    }
                    .onDelete { offsets in
                        tasks.remove(atOffsets: offsets)
                        if tasks.isEmpty {
                            tasks = [DraftTask()]
                        }
                    }
                    Button("Add task") {
                        tasks.append(DraftTask())
                    }
                }
            }
            .navigationTitle("New plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("savePlan")
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && tasks.contains { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func save() {
        let now = Date.now
        let plan = GoalPlan(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            createdAt: now,
            updatedAt: now,
            source: .manual,
            preferredLocaleIdentifier: locale.identifier
        )
        let cleaned = tasks.compactMap { task -> (String, Int)? in
            let taskTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !taskTitle.isEmpty else {
                return nil
            }
            return (taskTitle, task.estimatedPomodoros)
        }
        plan.tasks = cleaned.enumerated().map { index, item in
            PlanTask(
                title: item.0,
                position: index,
                estimatedPomodoros: item.1,
                createdAt: now,
                updatedAt: now
            )
        }
        modelContext.insert(plan)
        try? modelContext.save()
        dismiss()
    }
}

private struct DraftTask: Identifiable {
    let id = UUID()
    var title = ""
    var estimatedPomodoros = 1
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview {
    PlanEditorView()
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
