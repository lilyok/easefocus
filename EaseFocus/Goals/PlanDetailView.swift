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
    @State private var pendingSearch: ExternalSearchRequest?

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
                        onMoveDown: { moveTask(task, direction: .down) },
                        onPersistQuery: { query in
                            persistSearchQuery(query, on: task)
                        },
                        onSearch: { query in
                            pendingSearch = ExternalSearchOpening.request(from: query)
                        }
                    )
                    .id(task.id)
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
                Text("Add a resource search when a Google query would help. Search Google opens in your browser after you confirm.")
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
        .externalSearchConfirmation($pendingSearch)
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

    private func persistSearchQuery(_ query: String?, on task: PlanTask) {
        commit(
            apply: {
                task.searchQuery = query
                task.updatedAt = .now
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
    var onPersistQuery: (String?) -> Void
    var onSearch: (String) -> Void

    @State private var queryDraft: String
    @State private var isAddingQuery: Bool

    init(
        task: PlanTask,
        isStartEnabled: Bool,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onMarkCompleted: @escaping () -> Void,
        onStart: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onPersistQuery: @escaping (String?) -> Void,
        onSearch: @escaping (String) -> Void
    ) {
        self.task = task
        self.isStartEnabled = isStartEnabled
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onMarkCompleted = onMarkCompleted
        self.onStart = onStart
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onPersistQuery = onPersistQuery
        self.onSearch = onSearch
        _queryDraft = State(initialValue: task.searchQuery ?? "")
        _isAddingQuery = State(initialValue: false)
    }

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
            TaskResourceSearchControls(
                taskID: task.id,
                state: ResourceSearchControlPolicy.savedPlan(
                    hasQuery: ResourceSearchControlPolicy.hasQuery(task.searchQuery)
                        || ResourceSearchControlPolicy.hasQuery(queryDraft),
                    isAdding: isAddingQuery
                ),
                query: $queryDraft,
                onAdd: {
                    isAddingQuery = true
                },
                onRemove: {
                    queryDraft = ""
                    isAddingQuery = false
                    onPersistQuery(nil)
                },
                onSearch: onSearch
            )
            .onChange(of: queryDraft) { _, newValue in
                persistIfValid(newValue)
            }
            .onChange(of: task.searchQuery) { _, newValue in
                guard case .success(let draftValue) = SearchQueryValidator.validateOptional(queryDraft) else {
                    return
                }
                if draftValue != newValue {
                    queryDraft = newValue ?? ""
                    if newValue == nil {
                        isAddingQuery = false
                    }
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

    private func persistIfValid(_ raw: String) {
        switch SearchQueryValidator.validateOptional(raw) {
        case .success(let query):
            if query != task.searchQuery {
                onPersistQuery(query)
            }
        case .failure:
            break
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
