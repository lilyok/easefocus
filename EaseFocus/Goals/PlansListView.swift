import SwiftData
import SwiftUI

struct PlansListView: View {
    @Environment(\.locale) private var locale
    @Environment(\.foundationModelClient) private var foundationModelClient
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GoalPlan.updatedAt, order: .reverse) private var plans: [GoalPlan]
    @State private var isCreatingPlan = false

    private var activePlans: [GoalPlan] {
        plans.filter { $0.status == .active || $0.status == .paused }
    }

    private var archivedPlans: [GoalPlan] {
        plans.filter { $0.status == .completed || $0.status == .archived }
    }

    private var availability: FoundationModelAvailability {
        foundationModelClient.currentAvailability(locale: locale)
    }

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    VStack(spacing: FocusSpacing.large) {
                        if !availability.allowsGeneration {
                            AvailabilityNotice(availability: availability)
                                .padding(.horizontal)
                        }
                        ContentUnavailableView {
                            VStack(spacing: FocusSpacing.medium) {
                                EaseFocusMark(size: 64)
                                Text(PlansCopy.emptyTitle)
                                    .font(FocusTypography.title)
                                    .foregroundStyle(Color.focusPrimary)
                            }
                        } description: {
                            Text(PlansCopy.emptyDescription)
                        } actions: {
                            Button(PlansCopy.createPlan, systemImage: "plus") {
                                isCreatingPlan = true
                            }
                            .accessibilityIdentifier("createPlanFromPlans")
                        }
                    }
                } else {
                    List {
                        if !activePlans.isEmpty {
                            Section {
                                ForEach(activePlans) { plan in
                                    NavigationLink(value: plan) {
                                        PlanRowView(plan: plan)
                                    }
                                }
                            } header: {
                                Text(PlansCopy.active)
                            }
                        }
                        if !archivedPlans.isEmpty {
                            Section {
                                ForEach(archivedPlans) { plan in
                                    NavigationLink(value: plan) {
                                        PlanRowView(plan: plan)
                                    }
                                }
                            } header: {
                                Text(PlansCopy.archived)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.focusBackground)
            .navigationTitle(PlansCopy.navigationTitle)
            .navigationDestination(for: GoalPlan.self) { plan in
                PlanDetailView(plan: plan)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(PlansCopy.createPlan, systemImage: "plus") {
                        isCreatingPlan = true
                    }
                }
            }
            .sheet(isPresented: $isCreatingPlan) {
                CreatePlanView(availability: availability)
                    .environment(\.modelContext, modelContext)
            }
        }
    }
}

private struct PlanRowView: View {
    @Environment(\.locale) private var locale
    let plan: GoalPlan

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            Text(plan.title)
                .font(FocusTypography.body)
            Text(ProgressPresentation.planTaskLine(
                open: plan.pendingTasks.count,
                done: plan.orderedTasks.filter { $0.status == .completed }.count,
                locale: locale
            ))
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PlansListView()
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
        .environment(\.planRefinementClient, PreviewPlanRefinementClient())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
