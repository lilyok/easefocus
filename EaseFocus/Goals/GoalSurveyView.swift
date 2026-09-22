import SwiftUI

struct GoalSurveyView: View {
    @Binding var survey: GoalSurvey
    var availability: FoundationModelAvailability
    var errorMessage: String?
    var isGenerating: Bool
    var isCompactRequest = false
    var onGenerate: () -> Void
    var onCreateManually: () -> Void
    var onCancel: () -> Void

    var body: some View {
        FocusScreenStack {
            if !availability.allowsGeneration {
                AvailabilityNotice(availability: availability)
                    .focusCard()
            }

            VStack(alignment: .leading, spacing: FocusSpacing.small) {
                TextField(SurveyCopy.goalPlaceholder, text: $survey.goal, axis: .vertical)
                    .focusField()
                Text(isCompactRequest ? SurveyCopy.requestHint : SurveyCopy.goalHint)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }
            .focusCard()

            if !isCompactRequest {
                detailedSurveyFields
            }

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(Color.focusError)
                    .focusCard()
            }

            FocusCapsuleButton(
                title: SurveyCopy.generate,
                enabled: survey.isReadyToGenerate && availability.allowsGeneration && !isGenerating,
                identifier: "generatePlan",
                action: onGenerate
            )
            FocusCapsuleButton(
                title: SurveyCopy.createManually,
                fill: Color.focusPrimary.opacity(0.75),
                enabled: !isGenerating,
                identifier: "createManually",
                action: onCreateManually
            )
        }
        .navigationTitle(isCompactRequest ? AppCopy.taskAdviser : SurveyCopy.navigationTitle)
        .toolbar {
            if isGenerating {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SurveyCopy.stop, action: onCancel)
                }
            } else if !isCompactRequest {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SurveyCopy.cancel, action: onCancel)
                }
            }
        }
        .overlay {
            if isGenerating {
                ProgressView(SurveyCopy.generating)
                    .padding(FocusSpacing.large)
                    .background(Color.focusSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var detailedSurveyFields: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            Picker(selection: $survey.experience) {
                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                    Text(level.title).tag(level)
                }
            } label: {
                Text(SurveyCopy.experience)
            }
            Text(SurveyCopy.experienceHint)
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
        }
        .focusCard()

        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            TextField(SurveyCopy.successPlaceholder, text: $survey.successOutcome, axis: .vertical)
                .focusField()
            Text(SurveyCopy.successHint)
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
        }
        .focusCard()

        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            Stepper(value: $survey.sessionsPerWeek, in: GoalSurvey.sessionsPerWeekRange) {
                Text(SurveyCopy.sessionsPerWeek(survey.sessionsPerWeek))
            }
            Text(SurveyCopy.sessionsHint)
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
        }
        .focusCard()

        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            Toggle(SurveyCopy.deadlineToggle, isOn: $survey.hasDeadline)
            if survey.hasDeadline {
                DatePicker(
                    selection: $survey.deadline,
                    displayedComponents: .date
                ) {
                    Text(SurveyCopy.deadline)
                }
            }
            Text(SurveyCopy.deadlineHint)
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
        }
        .focusCard()

        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            TextField(SurveyCopy.constraintsPlaceholder, text: $survey.constraints, axis: .vertical)
                .focusField()
            Text(SurveyCopy.constraintsHint)
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
        }
        .focusCard()
    }
}

#Preview {
    NavigationStack {
        GoalSurveyView(
            survey: .constant(GoalSurvey()),
            availability: .available,
            errorMessage: nil,
            isGenerating: false,
            onGenerate: {},
            onCreateManually: {},
            onCancel: {}
        )
    }
}
