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
                TextField("What do you want to achieve?", text: $survey.goal, axis: .vertical)
                Text("This becomes the plan’s focus.")
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Current experience", selection: $survey.experience) {
                    ForEach(ExperienceLevel.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }
                Text("Used to keep tasks at the right difficulty.")
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("What would make this plan successful?", text: $survey.successOutcome, axis: .vertical)
                Text("Helps the draft aim at a concrete outcome.")
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Stepper(value: $survey.sessionsPerWeek, in: GoalSurvey.sessionsPerWeekRange) {
                    Text("\(survey.sessionsPerWeek) focus sessions a week")
                }
                Text("Keeps the plan sized to the time you actually have.")
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("I have a deadline", isOn: $survey.hasDeadline)
                if survey.hasDeadline {
                    DatePicker("Deadline", selection: $survey.deadline, displayedComponents: .date)
                }
                Text("Optional. Used only to pace the work.")
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("Preferences or constraints", text: $survey.constraints, axis: .vertical)
                Text("Optional. Examples: no evenings, keep sessions short, avoid public speaking.")
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
                Button("Create manually", action: onCreateManually)
                    .disabled(isGenerating)
                    .accessibilityIdentifier("createManually")
            }
        }
        .disabled(isGenerating)
        .navigationTitle("New plan")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(isGenerating ? "Stop" : "Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isGenerating {
                    ProgressView()
                } else {
                    Button("Generate", action: onGenerate)
                        .disabled(!survey.isReadyToGenerate || !availability.allowsGeneration)
                        .accessibilityIdentifier("generatePlan")
                }
            }
        }
        .overlay {
            if isGenerating {
                ProgressView("Generating a draft…")
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
