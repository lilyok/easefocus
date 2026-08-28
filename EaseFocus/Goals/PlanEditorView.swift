import SwiftData
import SwiftUI

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let source: PlanSource
    private let survey: GoalSurvey?
    private let onRegenerate: (() -> Void)?

    @State private var title: String
    @State private var details: String
    @State private var tasks: [DraftTask]

    init(
        draft: DraftPlanBlueprint? = nil,
        source: PlanSource = .manual,
        survey: GoalSurvey? = nil,
        onRegenerate: (() -> Void)? = nil
    ) {
        self.source = source
        self.survey = survey
        self.onRegenerate = onRegenerate
        _title = State(initialValue: draft?.title ?? "")
        _details = State(initialValue: draft?.summary ?? "")
        _tasks = State(
            initialValue: draft?.tasks.map { task in
                DraftTask(
                    title: task.title,
                    estimatedPomodoros: task.estimatedPomodoros,
                    searchQuery: task.searchQuery
                )
            } ?? [DraftTask()]
        )
    }

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
                    .onMove { offsets, destination in
                        tasks.move(fromOffsets: offsets, toOffset: destination)
                    }
                    Button("Add task") {
                        tasks.append(DraftTask())
                    }
                }
            }
            .navigationTitle(source == .generated ? "Review draft" : "New plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if let onRegenerate {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Regenerate", action: onRegenerate)
                            .accessibilityIdentifier("regenerateDraft")
                    }
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
        let cleaned = tasks.compactMap { task -> (title: String, estimatedPomodoros: Int, searchQuery: String)? in
            let taskTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !taskTitle.isEmpty else {
                return nil
            }
            return (taskTitle, task.estimatedPomodoros, task.searchQuery)
        }
        let plan = GoalPlanFactory.make(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            tasks: cleaned,
            source: source,
            survey: survey,
            locale: locale
        )
        modelContext.insert(plan)
        try? modelContext.save()
        dismiss()
    }
}

private struct DraftTask: Identifiable {
    let id = UUID()
    var title = ""
    var estimatedPomodoros = 1
    var searchQuery = ""
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
