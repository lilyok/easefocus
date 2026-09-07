import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.foundationModelClient) private var foundationModelClient
    @Environment(FocusTimerController.self) private var timer
    @Query(sort: \GoalPlan.updatedAt, order: .reverse)
    private var allPlans: [GoalPlan]

    @State private var isCreatingPlan = false
    @State private var taskPendingRemoval: PlanTask?
    @State private var expandedPlanIDs: Set<UUID> = []
    @State private var saveErrorMessage: String?
    @State private var isSaveAlertPresented = false
    @State private var pendingSaveRetry: (() -> Void)?
    @State private var pendingSearch: ExternalSearchRequest?

    private var plans: [GoalPlan] {
        allPlans.filter { $0.status == .active }
    }

    private var upcomingTasks: [PlanTask] {
        plans.flatMap(\.pendingTasks)
    }

    private var nextTask: PlanTask? {
        upcomingTasks.first
    }

    private var completedTasks: [PlanTask] {
        plans.flatMap(\.completedTasks)
    }

    private var plansWithLaterTasks: [GoalPlan] {
        plans.filter { !laterTasks(for: $0).isEmpty }
    }

    private var availability: FoundationModelAvailability {
        foundationModelClient.currentAvailability(locale: locale)
    }

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    VStack(spacing: FocusSpacing.large) {
                        accessNotices
                            .padding(.horizontal)
                        ContentUnavailableView {
                            Label(TodayCopy.readyToFocus, systemImage: "timer")
                        } description: {
                            Text(TodayCopy.emptyDescription)
                        } actions: {
                            Button(TodayCopy.createPlan, systemImage: "plus") {
                                isCreatingPlan = true
                            }
                            .accessibilityIdentifier("createPlan")
                            .frame(minWidth: FocusSpacing.minimumTapTarget, minHeight: FocusSpacing.minimumTapTarget)
                        }
                    }
                } else {
                    List {
                        if showsAccessNotices {
                            Section {
                                accessNotices
                            }
                        }

                        if let nextTask {
                            Section {
                                VStack(alignment: .leading, spacing: FocusSpacing.small) {
                                    if let plan = nextTask.plan {
                                        Text(plan.title)
                                            .font(FocusTypography.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    todayTaskRow(nextTask)
                                }
                                Button(TodayCopy.startFocus) {
                                    startFocus(on: nextTask)
                                }
                                .accessibilityIdentifier("startFocus")
                                .frame(
                                    minWidth: FocusSpacing.minimumTapTarget,
                                    minHeight: FocusSpacing.minimumTapTarget
                                )
                                .disabled(!timer.engine.canStartFocus)
                            } header: {
                                Text(TodayCopy.upNext)
                            }
                        }

                        if !plansWithLaterTasks.isEmpty {
                            Section {
                                ForEach(plansWithLaterTasks) { plan in
                                    DisclosureGroup(
                                        isExpanded: expansionBinding(for: plan)
                                    ) {
                                        ForEach(laterTasks(for: plan)) { task in
                                            todayTaskRow(task)
                                                .padding(.leading, FocusSpacing.small)
                                        }
                                        NavigationLink(value: plan) {
                                            Label(TodayCopy.openPlan, systemImage: "arrow.right.circle")
                                                .font(FocusTypography.footnote)
                                        }
                                        .accessibilityLabel(TodayCopy.openPlan(named: plan.title))
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(plan.title)
                                                .font(FocusTypography.body)
                                            Text(planProgressLabel(plan))
                                                .font(FocusTypography.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } header: {
                                Text(AppCopy.plans)
                            }
                        }

                        if !completedTasks.isEmpty {
                            Section {
                                ForEach(completedTasks) { task in
                                    todayTaskRow(task, canStart: false)
                                }
                            } header: {
                                Text(TodayCopy.done)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.focusBackground)
            .navigationTitle(TodayCopy.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(TodayCopy.createPlan, systemImage: "plus") {
                        isCreatingPlan = true
                    }
                }
            }
            .sheet(isPresented: $isCreatingPlan) {
                CreatePlanView(availability: availability)
                    .environment(\.modelContext, modelContext)
                    .environment(timer)
            }
            .navigationDestination(for: GoalPlan.self) { plan in
                PlanDetailView(plan: plan)
            }
            .confirmationDialog(
                Text(TaskCopy.removeTaskTitle),
                isPresented: Binding(
                    get: { taskPendingRemoval != nil },
                    set: { if !$0 { taskPendingRemoval = nil } }
                ),
                titleVisibility: .visible,
                presenting: taskPendingRemoval
            ) { task in
                Button(TaskCopy.remove, role: .destructive) {
                    remove(task)
                }
                Button(AppCopy.cancel, role: .cancel) {}
            } message: { task in
                Text(TaskCopy.deleteMessage(taskTitle: task.title))
            }
            .onAppear {
                if expandedPlanIDs.isEmpty, let firstPlan = plansWithLaterTasks.first {
                    expandedPlanIDs.insert(firstPlan.id)
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

    private func todayTaskRow(_ task: PlanTask, canStart: Bool? = nil) -> some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            TaskRowView(task: task) {
                toggleCompletion(task)
            }
            if let query = task.searchQuery,
               case .success(let validated) = SearchQueryValidator.validate(query) {
                Button(TodayCopy.searchGoogle) {
                    pendingSearch = ExternalSearchOpening.request(from: validated)
                }
                .accessibilityIdentifier("searchGoogle-\(task.id)")
            }
        }
        .taskRowActions(
            canStart: (canStart ?? timer.engine.canStartFocus) && task.status != .completed,
            onStart: { startFocus(on: task) },
            onRemove: { taskPendingRemoval = task }
        )
    }

    private func toggleCompletion(_ task: PlanTask) {
        commit(
            apply: {
                task.toggleCompletion()
                task.plan?.updatedAt = .now
            }
        )
    }

    private func startFocus(on task: PlanTask) {
        commit(
            apply: {
                task.plan?.moveTaskToFront(task)
            },
            onSuccess: {
                timer.startFocus(task: task)
            }
        )
    }

    private func remove(_ task: PlanTask) {
        commit(
            apply: {
                task.plan?.updatedAt = .now
                modelContext.delete(task)
            }
        )
        taskPendingRemoval = nil
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

    private func laterTasks(for plan: GoalPlan) -> [PlanTask] {
        plan.pendingTasks.filter { $0.id != nextTask?.id }
    }

    private func expansionBinding(for plan: GoalPlan) -> Binding<Bool> {
        Binding(
            get: { expandedPlanIDs.contains(plan.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedPlanIDs.insert(plan.id)
                } else {
                    expandedPlanIDs.remove(plan.id)
                }
            }
        )
    }

    private func planProgressLabel(_ plan: GoalPlan) -> String {
        let openCount = plan.pendingTasks.count
        let doneCount = plan.completedTasks.count
        return ProgressPresentation.planTaskLine(open: openCount, done: doneCount, locale: locale)
    }

    private var showsAccessNotices: Bool {
        timer.notificationAccess != .allowed || !availability.allowsGeneration
    }

    @ViewBuilder
    private var accessNotices: some View {
        if timer.notificationAccess != .allowed {
            NotificationAccessNotice(
                access: timer.notificationAccess,
                settingsLinkIdentifier: "todayOpenNotificationSettings"
            )
        }
        if !availability.allowsGeneration {
            AvailabilityNotice(availability: availability)
        }
    }
}

#Preview {
    TodayView()
        .environment(FocusTimerController())
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
