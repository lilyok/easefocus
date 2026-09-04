import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class PlanRefinementCoordinator {
    var request = ""
    var hasAttemptedGenerate = false
    private(set) var preview: PlanRefinementPreview?
    private(set) var isGenerating = false
    private(set) var generationError: String?
    private(set) var saveErrorMessage: String?
    var isSaveAlertPresented = false
    private(set) var didApply = false

    private var generateTask: Task<Void, Never>?
    private var generationID = UUID()
    private var pendingSaveRetry: (() -> Void)?

    var requestError: String? {
        PlanRefinementPresentation.requestError(
            for: request,
            hasAttemptedGenerate: hasAttemptedGenerate
        )
    }

    func isStale(plan: GoalPlan) -> Bool {
        guard let preview else {
            return false
        }
        return PlanRefinementPresentation.isStale(
            current: PlanSnapshot.capturing(plan),
            preview: preview
        )
    }

    func showsPreviousPreviewNotice(plan: GoalPlan) -> Bool {
        preview != nil && (
            isGenerating || (!(generationError ?? "").isEmpty && !isStale(plan: plan))
        )
    }

    func canConfirm(plan: GoalPlan) -> Bool {
        PlanRefinementPresentation.canConfirm(
            hasPreview: preview != nil,
            isGenerating: isGenerating,
            generationError: generationError,
            isStale: isStale(plan: plan)
        )
    }

    func generate(
        plan: GoalPlan,
        client: any PlanRefinementGenerating,
        locale: Locale
    ) {
        hasAttemptedGenerate = true
        if requestError != nil {
            return
        }

        let snapshot = PlanSnapshot.capturing(plan)
        let survey = GoalSurvey.decode(from: plan.surveySnapshot)
        let includesResourceSuggestions = PlanRefinementPresentation.includesResourceSuggestions(
            survey: survey
        )
        let capturedRequest = request
        let id = UUID()
        generationID = id
        isGenerating = true
        generationError = nil
        generateTask?.cancel()
        generateTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if self.generationID == id {
                    self.isGenerating = false
                    self.generateTask = nil
                }
            }
            do {
                let generated = try await client.generateRefinementPreview(
                    snapshot: snapshot,
                    request: capturedRequest,
                    locale: locale,
                    survey: survey,
                    includesResourceSuggestions: includesResourceSuggestions
                )
                guard !Task.isCancelled, self.generationID == id else {
                    return
                }
                self.preview = generated
            } catch let error as PlanRefinementGenerationError where error == .cancelled {
                return
            } catch is CancellationError {
                return
            } catch let error as PlanRefinementGenerationError {
                guard self.generationID == id else {
                    return
                }
                self.generationError = PlanRefinementGenerationErrorCopy.message(for: error)
            } catch {
                guard self.generationID == id else {
                    return
                }
                self.generationError = PlanRefinementGenerationErrorCopy.message(for: .generationFailed)
            }
        }
    }

    func cancelGeneration() {
        generationID = UUID()
        generateTask?.cancel()
        generateTask = nil
        isGenerating = false
    }

    func discardPreview() {
        cancelGeneration()
        preview = nil
        generationError = nil
        didApply = false
    }

    func confirm(
        plan: GoalPlan,
        context: ModelContext,
        save: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        guard let preview else {
            return
        }
        guard !isGenerating, (generationError ?? "").isEmpty else {
            return
        }
        if isStale(plan: plan) {
            generationError = PlanRefinementCopy.staleMessage
            return
        }

        switch PlanRefinementConfirming.apply(preview, to: plan, in: context, save: save) {
        case .applied:
            didApply = true
            saveErrorMessage = nil
            isSaveAlertPresented = false
            pendingSaveRetry = nil
        case .stale:
            generationError = PlanRefinementCopy.staleMessage
        case .saveFailed:
            saveErrorMessage = PersistenceSaveCopy.message
            isSaveAlertPresented = true
            pendingSaveRetry = { [weak self] in
                self?.confirm(plan: plan, context: context, save: save)
            }
        case .malformed:
            generationError = PlanRefinementCopy.malformedApply
        }
    }

    func retrySave() {
        pendingSaveRetry?()
    }

    func discardFailedSave() {
        isSaveAlertPresented = false
        saveErrorMessage = nil
        pendingSaveRetry = nil
    }
}
