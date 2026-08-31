import FoundationModels
import Testing
@testable import EaseFocus

struct PlanRefinementGenerationErrorTests {
    private let context = LanguageModelSession.GenerationError.Context(
        debugDescription: "Test"
    )

    @Test
    func reusesFoundationModelsErrorMapping() {
        let refusal = LanguageModelSession.GenerationError.Refusal(transcriptEntries: [])

        #expect(
            PlanRefinementGenerationError.from(
                FoundationModelGenerationErrorMapper.map(.refusal(refusal, context))
            ) == .refusal
        )
        #expect(
            PlanRefinementGenerationError.from(
                FoundationModelGenerationErrorMapper.map(.guardrailViolation(context))
            ) == .guardrailViolation
        )
        #expect(
            PlanRefinementGenerationError.from(
                FoundationModelGenerationErrorMapper.map(.unsupportedLanguageOrLocale(context))
            ) == .unsupportedLanguageOrLocale
        )
        #expect(
            PlanRefinementGenerationError.from(
                FoundationModelGenerationErrorMapper.map(.exceededContextWindowSize(context))
            ) == .contextLimitExceeded
        )
        #expect(
            PlanRefinementGenerationError.from(
                FoundationModelGenerationErrorMapper.map(.decodingFailure(context))
            ) == .generationFailed
        )
    }

    @Test
    func mapsDraftValidationErrorsAwayFromRefinementValidation() {
        #expect(
            PlanRefinementGenerationError.from(.validation(.emptyTitle))
                == .generationFailed
        )
        #expect(
            PlanRefinementGenerationError.from(.cancelled)
                == .cancelled
        )
        #expect(
            PlanRefinementGenerationError.from(.unavailable(.unavailable(.modelNotReady)))
                == .unavailable(.unavailable(.modelNotReady))
        )
    }
}
