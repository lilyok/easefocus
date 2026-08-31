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
                            Label("Ready to focus", systemImage: "timer")
                        } description: {
                            Text("Create a plan to start a focus session. Apple Intelligence is optional.")
                        } actions: {
                            Button("Create a plan", systemImage: "plus") {
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
                            Section("Up next") {
                                VStack(alignment: .leading, spacing: FocusSpacing.small) {
                                    if let plan = nextTask.plan {
                                        Text(plan.title)
                                            .font(FocusTypography.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    todayTaskRow(nextTask)
                                }
                                Button("Start focus") {
                                    startFocus(on: nextTask)
                                }
                                .accessibilityIdentifier("startFocus")
                                .disabled(!timer.engine.canStartFocus)
                            }
                        }

                        if !plansWithLaterTasks.isEmpty {
                            Section("Plans") {
                                ForEach(plansWithLaterTasks) { plan in
                                    DisclosureGroup(
                                        isExpanded: expansionBinding(for: plan)
                                    ) {
                                        ForEach(laterTasks(for: plan)) { task in
                                            todayTaskRow(task)
                                                .padding(.leading, FocusSpacing.small)
                                        }
                                        NavigationLink(value: plan) {
                                            Label("Open plan", systemImage: "arrow.right.circle")
                                                .font(FocusTypography.footnote)
                                        }
                                        .accessibilityLabel("Open \(plan.title) plan")
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
                            }
                        }

                        if !completedTasks.isEmpty {
                            Section("Done") {
                                ForEach(completedTasks) { task in
                                    todayTaskRow(task, canStart: false)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.focusBackground)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Create a plan", systemImage: "plus") {
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
                }
                Button("Cancel", role: .cancel) {}
            } message: { task in
                Text("“\(task.title)” will be deleted from the plan.")
            }
            .onAppear {
                if expandedPlanIDs.isEmpty, let firstPlan = plansWithLaterTasks.first {
                    expandedPlanIDs.insert(firstPlan.id)
                }
            }
        }
    }

    private func todayTaskRow(_ task: PlanTask, canStart: Bool? = nil) -> some View {
        TaskRowView(task: task) {
            toggleCompletion(task)
        }
        .taskRowActions(
            canStart: (canStart ?? timer.engine.canStartFocus) && task.status != .completed,
            onStart: { startFocus(on: task) },
            onRemove: { taskPendingRemoval = task }
        )
    }

    private func toggleCompletion(_ task: PlanTask) {
        task.toggleCompletion()
        task.plan?.updatedAt = .now
        try? modelContext.save()
    }

    private func startFocus(on task: PlanTask) {
        task.plan?.moveTaskToFront(task)
        try? modelContext.save()
        timer.startFocus(task: task)
    }

    private func remove(_ task: PlanTask) {
        task.plan?.updatedAt = .now
        modelContext.delete(task)
        try? modelContext.save()
        taskPendingRemoval = nil
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
        return "\(openCount) open · \(doneCount) done"
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
