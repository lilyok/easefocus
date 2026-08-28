import SwiftData
import SwiftUI

struct PlansListView: View {
    @Environment(\.locale) private var locale
    @Environment(\.foundationModelClient) private var foundationModelClient
    @Query(sort: \GoalPlan.updatedAt, order: .reverse) private var plans: [GoalPlan]
    @State private var isCreatingPlan = false

    private var activePlans: [GoalPlan] {
        plans.filter { $0.status == .active || $0.status == .paused }
    }

    private var archivedPlans: [GoalPlan] {
        plans.filter { $0.status == .completed || $0.status == .archived }
    }

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView {
                        Label("No plans yet", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Create a manual plan. Generated plans can wait until Apple Intelligence is available.")
                    } actions: {
                        Button("Create a plan", systemImage: "plus") {
                            isCreatingPlan = true
                        }
                        .accessibilityIdentifier("createPlanFromPlans")
                    }
                } else {
                    List {
                        if !activePlans.isEmpty {
                            Section("Active") {
                                ForEach(activePlans) { plan in
                                    NavigationLink(value: plan) {
                                        PlanRowView(plan: plan)
                                    }
                                }
                            }
                        }
                        if !archivedPlans.isEmpty {
                            Section("Archived") {
                                ForEach(archivedPlans) { plan in
                                    NavigationLink(value: plan) {
                                        PlanRowView(plan: plan)
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.focusBackground)
            .navigationTitle("Plans")
            .navigationDestination(for: GoalPlan.self) { plan in
                PlanDetailView(plan: plan)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Create a plan", systemImage: "plus") {
                        isCreatingPlan = true
                    }
                }
            }
            .sheet(isPresented: $isCreatingPlan) {
                CreatePlanView(allowsGeneration: foundationModelClient.currentAvailability(locale: locale).allowsGeneration)
            }
        }
    }
}

private struct PlanRowView: View {
    let plan: GoalPlan

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            Text(plan.title)
                .font(FocusTypography.body)
            Text("\(plan.pendingTasks.count) open · \(plan.orderedTasks.filter { $0.status == .completed }.count) done")
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PlansListView()
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
