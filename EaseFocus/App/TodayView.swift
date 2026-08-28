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

    private var plans: [GoalPlan] {
        allPlans.filter { $0.status == .active }
    }

    private var upcomingTasks: [PlanTask] {
        plans.flatMap(\.pendingTasks)
    }

    private var nextTask: PlanTask? {
        upcomingTasks.first
    }

    private var availability: FoundationModelAvailability {
        foundationModelClient.currentAvailability(locale: locale)
    }

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
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
                } else {
                    List {
                        if !availability.allowsGeneration {
                            Section {
                                AvailabilityNotice(availability: availability)
                            }
                        }

                        if let nextTask {
                            Section("Up next") {
                                TaskRowView(task: nextTask)
                                Button("Start focus") {
                                    timer.startFocus(task: nextTask)
                                }
                                .accessibilityIdentifier("startFocus")
                                .disabled(!timer.engine.canStartFocus)
                            }
                        }

                        if upcomingTasks.count > 1 {
                            Section("Later") {
                                ForEach(upcomingTasks.dropFirst()) { task in
                                    TaskRowView(task: task)
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
                CreatePlanView(allowsGeneration: availability.allowsGeneration)
            }
            .navigationDestination(for: GoalPlan.self) { plan in
                PlanDetailView(plan: plan)
            }
        }
    }
}

#Preview {
    TodayView()
        .environment(FocusTimerController())
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
