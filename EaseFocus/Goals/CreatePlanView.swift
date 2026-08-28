import SwiftData
import SwiftUI

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.foundationModelClient) private var foundationModelClient

    @State private var mode: Mode
    @State private var survey = GoalSurvey()
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var generateTask: Task<Void, Never>?

    init(allowsGeneration: Bool) {
        _mode = State(initialValue: allowsGeneration ? .survey : .manual)
    }

    var body: some View {
        switch mode {
        case .survey:
            NavigationStack {
                GoalSurveyView(
                    survey: $survey,
                    errorMessage: errorMessage,
                    isGenerating: isGenerating,
                    onGenerate: generate,
                    onCreateManually: {
                        cancelGeneration()
                        mode = .manual
                    },
                    onCancel: {
                        if isGenerating {
                            cancelGeneration()
                        } else {
                            dismiss()
                        }
                    }
                )
            }
        case .review(let draft):
            PlanEditorView(
                draft: draft,
                source: .generated,
                survey: survey,
                onRegenerate: {
                    mode = .survey
                    generate()
                }
            )
        case .manual:
            PlanEditorView()
        }
    }

    private func generate() {
        errorMessage = nil
        isGenerating = true
        generateTask?.cancel()
        generateTask = Task { @MainActor in
            do {
                let draft = try await foundationModelClient.generateDraftPlan(
                    survey: survey,
                    locale: locale
                )
                guard !Task.isCancelled else {
                    breakGenerating()
                    return
                }
                mode = .review(draft)
                isGenerating = false
                generateTask = nil
            } catch let error as FoundationModelClientError where error == .cancelled {
                breakGenerating()
            } catch let error as FoundationModelClientError {
                errorMessage = FoundationModelClientErrorCopy.message(for: error)
                isGenerating = false
                generateTask = nil
            } catch is CancellationError {
                breakGenerating()
            } catch {
                errorMessage = FoundationModelClientErrorCopy.message(for: .generationFailed)
                isGenerating = false
                generateTask = nil
            }
        }
    }

    private func cancelGeneration() {
        generateTask?.cancel()
        generateTask = nil
        isGenerating = false
    }

    private func breakGenerating() {
        isGenerating = false
        generateTask = nil
    }
}

private enum Mode {
    case survey
    case review(DraftPlanBlueprint)
    case manual
}

#Preview("Generated") {
    CreatePlanView(allowsGeneration: true)
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}

#Preview("Manual") {
    CreatePlanView(allowsGeneration: false)
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
