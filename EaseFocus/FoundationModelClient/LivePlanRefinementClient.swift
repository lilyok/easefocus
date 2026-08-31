import Foundation
import FoundationModels

nonisolated struct LivePlanRefinementClient: PlanRefinementGenerating {
    func currentAvailability(locale: Locale) -> FoundationModelAvailability {
        LiveFoundationModelClient().currentAvailability(locale: locale)
    }

    func generateRefinementPreview(
        snapshot: PlanSnapshot,
        request: String,
        locale: Locale,
        survey: GoalSurvey?,
        includesResourceSuggestions: Bool
    ) async throws -> PlanRefinementPreview {
        guard !Task.isCancelled else {
            throw PlanRefinementGenerationError.cancelled
        }

        let trimmedRequest: String
        do {
            trimmedRequest = try PlanRefinementPreviewFactory.validatedRequest(request)
        } catch let error as PlanRefinementValidationError {
            throw PlanRefinementGenerationError.validation(error)
        }

        let availability = currentAvailability(locale: locale)
        guard availability.allowsGeneration else {
            throw PlanRefinementGenerationError.unavailable(availability)
        }

        let session = LanguageModelSession {
            PlanRefinementPrompt.instructions(
                locale: locale,
                includesResourceSuggestions: includesResourceSuggestions
            )
        }

        let generated: GenerablePlanRefinement
        do {
            generated = try await session.respond(
                to: PlanRefinementPrompt.userMessage(
                    snapshot: snapshot,
                    request: trimmedRequest,
                    locale: locale,
                    survey: survey,
                    includesResourceSuggestions: includesResourceSuggestions
                ),
                generating: GenerablePlanRefinement.self
            ).content
        } catch is CancellationError {
            throw PlanRefinementGenerationError.cancelled
        } catch let error as LanguageModelSession.GenerationError {
            if Task.isCancelled {
                throw PlanRefinementGenerationError.cancelled
            }
            throw PlanRefinementGenerationError.from(FoundationModelGenerationErrorMapper.map(error))
        } catch {
            if Task.isCancelled {
                throw PlanRefinementGenerationError.cancelled
            }
            throw PlanRefinementGenerationError.generationFailed
        }

        guard !Task.isCancelled else {
            throw PlanRefinementGenerationError.cancelled
        }

        do {
            return try PlanRefinementPreviewFactory.make(
                snapshot: snapshot,
                request: trimmedRequest,
                proposal: PlanRefinementProposal(generated),
                includesResourceSuggestions: includesResourceSuggestions
            )
        } catch let error as PlanRefinementValidationError {
            throw PlanRefinementGenerationError.validation(error)
        }
    }
}
