import SwiftUI

struct GoalSurveyView: View {
    @Binding var survey: GoalSurvey
    var availability: FoundationModelAvailability
    var errorMessage: String?
    var isGenerating: Bool
    var onGenerate: () -> Void
    var onCreateManually: () -> Void
    var onCancel: () -> Void

    var body: some View {
        Form {
            if !availability.allowsGeneration {
                Section {
                    AvailabilityNotice(availability: availability)
                }
            }

            Section {
                TextField(SurveyCopy.goalPlaceholder, text: $survey.goal, axis: .vertical)
                Text(SurveyCopy.goalHint)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
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

            Section {
                TextField(SurveyCopy.successPlaceholder, text: $survey.successOutcome, axis: .vertical)
                Text(SurveyCopy.successHint)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Stepper(value: $survey.sessionsPerWeek, in: GoalSurvey.sessionsPerWeekRange) {
                    Text(SurveyCopy.sessionsPerWeek(survey.sessionsPerWeek))
                }
                Text(SurveyCopy.sessionsHint)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
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

            Section {
                TextField(SurveyCopy.constraintsPlaceholder, text: $survey.constraints, axis: .vertical)
                Text(SurveyCopy.constraintsHint)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(ResourceSearchSuggestionCopy.surveyToggle, isOn: $survey.includesResourceSuggestions)
                    .accessibilityIdentifier("includeResourceSuggestions")
                Text(ResourceSearchSuggestionCopy.surveyExplanation)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage, !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(Color.focusError)
                }
            }

            Section {
                Button(SurveyCopy.createManually, action: onCreateManually)
                    .disabled(isGenerating)
                    .accessibilityIdentifier("createManually")
            }
        }
        .disabled(isGenerating)
        .navigationTitle(SurveyCopy.navigationTitle)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(isGenerating ? SurveyCopy.stop : SurveyCopy.cancel, action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isGenerating {
                    ProgressView()
                } else {
                    Button(SurveyCopy.generate, action: onGenerate)
                        .disabled(!survey.isReadyToGenerate || !availability.allowsGeneration)
                        .accessibilityIdentifier("generatePlan")
                }
            }
        }
        .overlay {
            if isGenerating {
                ProgressView(SurveyCopy.generating)
                    .padding(FocusSpacing.large)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
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
