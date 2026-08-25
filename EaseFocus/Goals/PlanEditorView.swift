import SwiftData
import SwiftUI

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var title = ""
    @State private var details = ""
    @State private var taskTitles: [String] = [""]

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    TextField("Title", text: $title)
                    TextField("Details", text: $details, axis: .vertical)
                }
                Section("Tasks") {
                    ForEach(taskTitles.indices, id: \.self) { index in
                        TextField("Task \(index + 1)", text: $taskTitles[index])
                    }
                    .onDelete { offsets in
                        taskTitles.remove(atOffsets: offsets)
                        if taskTitles.isEmpty {
                            taskTitles = [""]
                        }
                    }
                    Button("Add task") {
                        taskTitles.append("")
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
            && taskTitles.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
        let cleaned = taskTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        plan.tasks = cleaned.enumerated().map { index, taskTitle in
            PlanTask(title: taskTitle, position: index, createdAt: now, updatedAt: now)
        }
        modelContext.insert(plan)
        try? modelContext.save()
        dismiss()
    }
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
