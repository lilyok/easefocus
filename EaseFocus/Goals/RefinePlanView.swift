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
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560, idealHeight: 640, maxHeight: 780)
        #endif
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if coordinator.isGenerating {
                Button(PlanRefinementCopy.stop) {
                    coordinator.cancelGeneration()
                }
                .accessibilityIdentifier(PlanRefinementAccessibilityIdentifier.cancel)
            } else if coordinator.preview == nil {
                Button(PlanRefinementCopy.cancel) {
                    dismiss()
                }
                .accessibilityIdentifier(PlanRefinementAccessibilityIdentifier.cancel)
            } else {
                Button(PlanRefinementCopy.discard) {
                    coordinator.discardPreview()
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
                .disabled(!coordinator.canConfirm(plan: plan))
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
        ScrollView {
            VStack(alignment: .leading, spacing: FocusSpacing.large) {
                if let generationError = PlanRefinementPresentation.displayedGenerationError(
                    isStale: coordinator.isStale(plan: plan),
                    generationError: coordinator.generationError
                ) {
                    Text(generationError)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(Color.focusError)
                }

                if coordinator.isStale(plan: plan) {
                    VStack(alignment: .leading, spacing: FocusSpacing.small) {
                        Text(PlanRefinementCopy.staleTitle)
                            .font(FocusTypography.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .accessibilityAddTraits(.isHeader)
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
                }

                if coordinator.showsPreviousPreviewNotice(plan: plan) {
                    Text(PlanRefinementCopy.previousPreviewNotice)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }

                PlanSnapshotComparisonView(
                    before: preview.before,
                    after: preview.after,
                    summary: preview.changeSummary
                )

                if !coordinator.isStale(plan: plan) {
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
            .padding(FocusSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
