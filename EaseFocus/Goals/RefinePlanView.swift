import SwiftData
import SwiftUI

struct RefinePlanView: View {
    @Bindable var plan: GoalPlan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planRefinementClient) private var planRefinementClient
    @State private var coordinator = PlanRefinementCoordinator()

    var body: some View {
        NavigationStack {
            Group {
                if let preview = coordinator.preview {
                    previewList(preview)
                } else {
                    requestForm
                }
            }
            .background(Color.focusBackground)
            .navigationTitle(
                coordinator.preview == nil
                    ? PlanRefinementCopy.requestTitle
                    : PlanRefinementCopy.previewTitle
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbar }
            .overlay {
                if coordinator.isGenerating {
                    ProgressView(PlanRefinementCopy.generating)
                        .padding(FocusSpacing.large)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .persistenceSaveAlert(
                isPresented: $coordinator.isSaveAlertPresented,
                message: coordinator.saveErrorMessage,
                onRetry: { coordinator.retrySave() },
                onDiscard: { coordinator.discardFailedSave() }
            )
            .interactiveDismissDisabled(coordinator.isGenerating)
            .onChange(of: coordinator.didApply) { _, didApply in
                if didApply {
                    dismiss()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if coordinator.preview == nil {
                Button(
                    coordinator.isGenerating ? PlanRefinementCopy.stop : PlanRefinementCopy.cancel
                ) {
                    if coordinator.isGenerating {
                        coordinator.cancelGeneration()
                    } else {
                        dismiss()
                    }
                }
                .accessibilityIdentifier(PlanRefinementAccessibilityIdentifier.cancel)
            } else {
                Button(PlanRefinementCopy.discard) {
                    coordinator.discardPreview()
                    dismiss()
                }
                .accessibilityIdentifier(PlanRefinementAccessibilityIdentifier.discard)
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            if coordinator.preview == nil {
                Button(PlanRefinementCopy.generate) {
                    coordinator.generate(
                        plan: plan,
                        client: planRefinementClient,
                        locale: locale
                    )
                }
                .disabled(coordinator.isGenerating)
                .accessibilityIdentifier(PlanRefinementAccessibilityIdentifier.generate)
            } else {
                Button(PlanRefinementCopy.confirm) {
                    coordinator.confirm(plan: plan, context: modelContext)
                }
                .disabled(coordinator.isGenerating || coordinator.isStale(plan: plan))
                .accessibilityIdentifier(PlanRefinementAccessibilityIdentifier.confirm)
            }
        }
    }

    private var requestForm: some View {
        Form {
            Section {
                TextField(
                    PlanRefinementCopy.requestPrompt,
                    text: $coordinator.request,
                    axis: .vertical
                )
                .disabled(coordinator.isGenerating)
                .accessibilityIdentifier(PlanRefinementAccessibilityIdentifier.request)
                if let requestError = coordinator.requestError {
                    Text(requestError)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(Color.focusError)
                        .accessibilityIdentifier("refinePlanRequestError")
                }
                Text(PlanRefinementCopy.examples)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text(PlanRefinementCopy.protectedExplanation)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            if let generationError = coordinator.generationError, !generationError.isEmpty {
                Section {
                    Text(generationError)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(Color.focusError)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func previewList(_ preview: PlanRefinementPreview) -> some View {
        List {
            Section {
                Text(preview.changeSummary)
                    .font(FocusTypography.body)
            }

            if coordinator.isStale(plan: plan) {
                Section {
                    Text(PlanRefinementCopy.staleTitle)
                        .font(FocusTypography.body)
                        .foregroundStyle(Color.focusError)
                    Text(PlanRefinementCopy.staleMessage)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(Color.focusError)
                    Button(PlanRefinementCopy.generateAgain) {
                        coordinator.generate(
                            plan: plan,
                            client: planRefinementClient,
                            locale: locale
                        )
                    }
                    .disabled(coordinator.isGenerating)
                    .accessibilityIdentifier(PlanRefinementAccessibilityIdentifier.generate)
                }
            } else if let generationError = coordinator.generationError, !generationError.isEmpty {
                Section {
                    Text(generationError)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(Color.focusError)
                }
            }

            Section(PlanRefinementCopy.beforeSection) {
                ForEach(PlanRefinementPresentation.beforeTasks(for: preview), id: \.id) { task in
                    refinementTaskRow(task: task, kind: nil)
                }
            }

            Section(PlanRefinementCopy.afterSection) {
                ForEach(PlanRefinementPresentation.displayedTasks(for: preview)) { row in
                    refinementTaskRow(task: row.after, kind: row.kind, before: row.before)
                }
            }

            if !coordinator.isStale(plan: plan) {
                Section {
                    Button(PlanRefinementCopy.generateAgain) {
                        coordinator.generate(
                            plan: plan,
                            client: planRefinementClient,
                            locale: locale
                        )
                    }
                    .disabled(coordinator.isGenerating)
                    .accessibilityIdentifier(PlanRefinementAccessibilityIdentifier.generate)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func refinementTaskRow(
        task: TaskSnapshot,
        kind: PlanRefinementChangeKind?,
        before: TaskSnapshot? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let kind, let badge = PlanRefinementCopy.badge(for: kind) {
                    Text(badge)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(Color.focusAccent)
                }
                if let status = PlanRefinementCopy.statusLabel(for: task.status) {
                    Text(status)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Text(task.title)
                .font(FocusTypography.body)
                .strikethrough(task.status == .archived)
            if kind == .updated, let before, before.title != task.title {
                Text("Was: \(before.title)")
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("\(task.estimatedPomodoros) estimated sessions")
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier(rowAccessibilityIdentifier(kind: kind))
    }

    private func rowAccessibilityIdentifier(kind: PlanRefinementChangeKind?) -> String {
        switch kind {
        case .added, .updated, .archived, .reordered:
            return "refinePlanChangedTask"
        case .protected, .unchanged, nil:
            return "refinePlanProtectedTask"
        }
    }
}

#Preview {
    let plan = GoalPlan(
        title: "Spanish greetings",
        details: "A short speaking plan.",
        tasks: [
            PlanTask(title: "Practice hola", position: 0),
            PlanTask(title: "Record a greeting", position: 1, status: .completed),
        ]
    )
    return RefinePlanView(plan: plan)
        .environment(\.planRefinementClient, PreviewPlanRefinementClient())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
