import SwiftData
import SwiftUI

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let source: PlanSource
    private let survey: GoalSurvey?
    private let onRegenerate: (() -> Void)?
    private let onClose: (() -> Void)?

    @State private var title: String
    @State private var details: String
    @State private var tasks: [DraftTask]
    @State private var insertedPlan: GoalPlan?
    @State private var saveErrorMessage: String?
    @State private var isSaveAlertPresented = false
    @State private var pendingSaveRetry: (() -> Void)?

    init(
        draft: DraftPlanBlueprint? = nil,
        source: PlanSource = .manual,
        survey: GoalSurvey? = nil,
        onRegenerate: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.source = source
        self.survey = survey
        self.onRegenerate = onRegenerate
        self.onClose = onClose
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
            List {
                Section {
                    VStack(alignment: .leading, spacing: FocusSpacing.small) {
                        TextField(PlanEditorCopy.title, text: $title)
                            .focusField()
                        TextField(PlanEditorCopy.details, text: $details, axis: .vertical)
                            .focusField()
                    }
                    .focusCard()
                    .focusListRow()
                } header: {
                    FocusSectionHeader(title: PlanEditorCopy.plan)
                }

                Section {
                    ForEach($tasks) { $task in
                        VStack(alignment: .leading, spacing: FocusSpacing.small) {
                            TextField(PlanEditorCopy.taskTitle, text: $task.title)
                                .focusField()
                            Stepper(value: $task.estimatedPomodoros, in: DraftPlanValidator.pomodoroRange) {
                                Text(TaskCopy.estimatedSessions(task.estimatedPomodoros))
                                    .font(FocusTypography.footnote)
                                    .foregroundStyle(Color.focusPrimary)
                            }
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
                        .focusCard()
                        .focusListRow()
                        .swipeToRemove {
                            tasks.removeAll { $0.id == task.id }
                            if tasks.isEmpty {
                                tasks = [DraftTask()]
                            }
                        }
                        .contextMenu {
                            Button(TaskCopy.remove, role: .destructive) {
                                tasks.removeAll { $0.id == task.id }
                                if tasks.isEmpty {
                                    tasks = [DraftTask()]
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: FocusSpacing.medium) {
                        FocusCapsuleButton(title: PlanEditorCopy.addTask) {
                            tasks.append(DraftTask())
                        }
                        if source == .manual {
                            Text(PlanEditorCopy.reorderFooter)
                                .font(FocusTypography.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let onRegenerate {
                            FocusCapsuleButton(
                                title: PlanEditorCopy.regenerate,
                                identifier: "regenerateDraft",
                                action: onRegenerate
                            )
                        }
                        FocusCapsuleButton(
                            title: PlanEditorCopy.save,
                            enabled: canSave,
                            identifier: "savePlan",
                            action: save
                        )
                        FocusCapsuleButton(
                            title: PlanEditorCopy.cancel,
                            fill: Color.focusError,
                            action: cancel
                        )
                    }
                    .focusListRow()
                } header: {
                    FocusSectionHeader(title: PlanEditorCopy.tasks)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .focusScreen()
            .navigationTitle(source == .generated ? PlanEditorCopy.reviewDraft : PlanEditorCopy.newPlan)
            .persistenceSaveAlert(
                isPresented: $isSaveAlertPresented,
                message: saveErrorMessage,
                onRetry: { pendingSaveRetry?() },
                onDiscard: discardFailedSave
            )
        }
        .focusScreen()
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && tasks.contains { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func save() {
        let cleaned = tasks.compactMap { task -> (title: String, estimatedPomodoros: Int, searchQuery: String?)? in
            let taskTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !taskTitle.isEmpty else {
                return nil
            }
            guard case .success(let searchQuery) = SearchQueryValidator.validateOptional("") else {
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
            close()
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
        close()
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func moveTask(_ id: UUID, direction: TaskMoveDirection) {
        tasks = TaskOrdering.reordered(tasks, moving: id, direction: direction)
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
