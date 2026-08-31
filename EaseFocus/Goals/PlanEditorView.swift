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
    @State private var insertedPlan: GoalPlan?
    @State private var saveErrorMessage: String?
    @State private var isSaveAlertPresented = false
    @State private var pendingSaveRetry: (() -> Void)?
    @State private var pendingSearch: ExternalSearchRequest?

    private var showsResourceSearch: Bool {
        source == .generated && survey?.includesResourceSuggestions == true
    }

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
                Section {
                    ForEach($tasks) { $task in
                        VStack(alignment: .leading, spacing: FocusSpacing.small) {
                            TextField("Task title", text: $task.title)
                            Stepper(value: $task.estimatedPomodoros, in: DraftPlanValidator.pomodoroRange) {
                                Text("\(task.estimatedPomodoros) estimated sessions")
                                    .font(FocusTypography.footnote)
                            }
                            TaskResourceSearchControls(
                                taskID: task.id,
                                state: ResourceSearchControlPolicy.draftCreation(
                                    source: source,
                                    includesResourceSuggestions: survey?.includesResourceSuggestions == true,
                                    hasQuery: ResourceSearchControlPolicy.hasQuery(task.searchQuery),
                                    isAdding: task.isAddingResourceSearch
                                ),
                                query: $task.searchQuery,
                                onAdd: {
                                    task.isAddingResourceSearch = true
                                },
                                onRemove: {
                                    task.searchQuery = ""
                                    task.isAddingResourceSearch = false
                                },
                                onSearch: { query in
                                    pendingSearch = ExternalSearchOpening.request(from: query)
                                }
                            )
                            HStack {
                                Spacer()
                                let index = tasks.firstIndex(where: { $0.id == task.id }) ?? 0
                                TaskReorderControls(
                                    canMoveUp: index > 0,
                                    canMoveDown: index < tasks.count - 1,
                                    onMoveUp: { moveTask(task.id, direction: .up) },
                                    onMoveDown: { moveTask(task.id, direction: .down) }
                                )
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
                } header: {
                    Text("Tasks")
                } footer: {
                    if showsResourceSearch {
                        Text("Resource search suggestions can be edited or removed. A query leaves EaseFocus only when you confirm Search Google.")
                    } else if source == .manual {
                        Text("Use the arrow buttons to set the task order.")
                    }
                }
            }
            .navigationTitle(source == .generated ? "Review draft" : "New plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
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
            .persistenceSaveAlert(
                isPresented: $isSaveAlertPresented,
                message: saveErrorMessage,
                onRetry: { pendingSaveRetry?() },
                onDiscard: discardFailedSave
            )
            .externalSearchConfirmation($pendingSearch)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && tasks.contains { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && tasks.allSatisfy {
                searchQueryError(for: showsResourceSearch ? $0.searchQuery : "") == nil
            }
    }

    private func save() {
        let cleaned = tasks.compactMap { task -> (title: String, estimatedPomodoros: Int, searchQuery: String?)? in
            let taskTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !taskTitle.isEmpty else {
                return nil
            }
            guard case .success(let searchQuery) = SearchQueryValidator.validateOptional(
                showsResourceSearch ? task.searchQuery : ""
            ) else {
                return nil
            }
            return (taskTitle, task.estimatedPomodoros, searchQuery)
        }
        guard cleaned.count == tasks.filter({
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }).count else {
            return
        }
        if insertedPlan == nil {
            do {
                let plan = try GoalPlanFactory.make(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    details: details.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    tasks: cleaned,
                    source: source,
                    survey: survey,
                    locale: locale
                )
                modelContext.insert(plan)
                insertedPlan = plan
            } catch {
                return
            }
        }
        savePendingChanges()
    }

    private func savePendingChanges() {
        switch PersistenceSaving.result(of: { try modelContext.save() }) {
        case .saved:
            saveErrorMessage = nil
            isSaveAlertPresented = false
            pendingSaveRetry = nil
            dismiss()
        case .failed(let message):
            saveErrorMessage = message
            isSaveAlertPresented = true
            pendingSaveRetry = savePendingChanges
        }
    }

    private func discardFailedSave() {
        modelContext.rollback()
        insertedPlan = nil
        saveErrorMessage = nil
        isSaveAlertPresented = false
        pendingSaveRetry = nil
    }

    private func cancel() {
        if insertedPlan != nil {
            modelContext.rollback()
            insertedPlan = nil
        }
        dismiss()
    }

    private func moveTask(_ id: UUID, direction: TaskMoveDirection) {
        tasks = TaskOrdering.reordered(tasks, moving: id, direction: direction)
    }

    private func searchQueryError(for query: String) -> SearchQueryValidationError? {
        guard case .failure(let error) = SearchQueryValidator.validateOptional(query) else {
            return nil
        }
        return error
    }
}

private struct DraftTask: Identifiable {
    let id = UUID()
    var title = ""
    var estimatedPomodoros = 1
    var searchQuery = ""
    var isAddingResourceSearch = false
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
