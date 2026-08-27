import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.foundationModelClient) private var foundationModelClient
    @Environment(\.locale) private var locale
    @Environment(FocusTimerController.self) private var timer

    @State private var draft: DraftPlanBlueprint?
    @State private var generationError: String?
    @State private var isGenerating = false
    @State private var sampleQuery = "beginner English pronunciation exercises"

    private var availability: FoundationModelAvailability {
        foundationModelClient.currentAvailability(locale: locale)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Timer") {
                    durationStepper("Focus minutes", seconds: focusSecondsBinding)
                    durationStepper("Short break", seconds: shortBreakBinding)
                    durationStepper("Long break", seconds: longBreakBinding)
                    Toggle("Start breaks automatically", isOn: autoBreakBinding)
                }

                Section("Apple Intelligence") {
                    AvailabilityNotice(availability: availability)
                    Button("Generate a sample draft") {
                        Task { await generateSampleDraft() }
                    }
                    .disabled(!availability.allowsGeneration || isGenerating)
                    .accessibilityIdentifier("generateSampleDraft")

                    if isGenerating {
                        ProgressView("Generating…")
                    }

                    if let draft {
                        Text(draft.title)
                            .font(FocusTypography.body)
                        Text(draft.summary)
                            .font(FocusTypography.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let generationError {
                        Text(generationError)
                            .font(FocusTypography.footnote)
                            .foregroundStyle(Color.focusError)
                    }
                }

                Section(ExternalSearchPrivacyCopy.title) {
                    Text(ExternalSearchPrivacyCopy.body)
                        .font(FocusTypography.footnote)

                    TextField("Search query", text: $sampleQuery)
                    Button("Search Google") {
                        openSampleSearch()
                    }
                    .disabled(GoogleSearchURL.make(from: sampleQuery) == nil)
                    .accessibilityIdentifier("searchGoogle")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.focusBackground)
            .navigationTitle("Settings")
        }
    }

    private var focusSecondsBinding: Binding<Int> {
        Binding(
            get: { timer.settings.focusSeconds },
            set: { timer.settings.focusSeconds = $0 }
        )
    }

    private var shortBreakBinding: Binding<Int> {
        Binding(
            get: { timer.settings.shortBreakSeconds },
            set: { timer.settings.shortBreakSeconds = $0 }
        )
    }

    private var longBreakBinding: Binding<Int> {
        Binding(
            get: { timer.settings.longBreakSeconds },
            set: { timer.settings.longBreakSeconds = $0 }
        )
    }

    private var autoBreakBinding: Binding<Bool> {
        Binding(
            get: { timer.settings.startBreaksAutomatically },
            set: { timer.settings.startBreaksAutomatically = $0 }
        )
    }

    private func durationStepper(_ title: String, seconds: Binding<Int>) -> some View {
        Stepper(value: Binding(
            get: { seconds.wrappedValue / 60 },
            set: { seconds.wrappedValue = max(60, $0 * 60) }
        ), in: 1...60) {
            Text("\(title): \(seconds.wrappedValue / 60)")
        }
    }

    private func generateSampleDraft() async {
        generationError = nil
        isGenerating = true
        defer { isGenerating = false }

        do {
            draft = try await foundationModelClient.generateDraftPlan(
                prompt: "Create a 3-task beginner plan for clearer English pronunciation. No URLs.",
                locale: locale
            )
        } catch let error as FoundationModelClientError {
            draft = nil
            generationError = FoundationModelClientErrorCopy.message(for: error)
        } catch {
            draft = nil
            generationError = FoundationModelClientErrorCopy.message(for: .generationFailed)
        }
    }

    private func openSampleSearch() {
        guard let url = GoogleSearchURL.make(from: sampleQuery) else {
            return
        }
        openURL(url)
    }
}

#Preview {
    SettingsView()
        .environment(FocusTimerController())
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
}
