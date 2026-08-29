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
                                todayTaskRow(nextTask)
                                Button("Start focus") {
                                    startFocus(on: nextTask)
                                }
                                .accessibilityIdentifier("startFocus")
                                .disabled(!timer.engine.canStartFocus)
                            }
                        }

                        if upcomingTasks.count > 1 {
                            Section("Later") {
                                ForEach(upcomingTasks.dropFirst()) { task in
                                    todayTaskRow(task)
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
