import FoundationModels
import Testing
@testable import EaseFocus

struct FoundationModelGenerationErrorTests {
    private let context = LanguageModelSession.GenerationError.Context(
        debugDescription: "Test"
    )

    @Test
    func mapsRefusal() {
        let refusal = LanguageModelSession.GenerationError.Refusal(transcriptEntries: [])

        #expect(
            FoundationModelGenerationErrorMapper.map(.refusal(refusal, context))
                == .refusal
        )
        #expect(
            FoundationModelClientErrorCopy.message(for: .refusal)
                .contains("Rephrase")
        )
    }

    @Test
    func mapsGuardrailViolation() {
        #expect(
            FoundationModelGenerationErrorMapper.map(.guardrailViolation(context))
                == .guardrailViolation
        )
        #expect(
            FoundationModelClientErrorCopy.message(for: .guardrailViolation)
                .contains("safety")
        )
    }

    @Test
    func mapsUnsupportedLanguageOrLocale() {
        #expect(
            FoundationModelGenerationErrorMapper.map(.unsupportedLanguageOrLocale(context))
                == .unsupportedLanguageOrLocale
        )
        #expect(
            FoundationModelClientErrorCopy.message(for: .unsupportedLanguageOrLocale)
                .contains("supported language")
        )
    }

    @Test
    func mapsContextLimit() {
        #expect(
            FoundationModelGenerationErrorMapper.map(.exceededContextWindowSize(context))
                == .contextLimitExceeded
        )
        #expect(
            FoundationModelClientErrorCopy.message(for: .contextLimitExceeded)
                .contains("Shorten")
        )
    }

    @Test
    func mapsOtherTypedGenerationErrorsToTheFallback() {
        #expect(
            FoundationModelGenerationErrorMapper.map(.decodingFailure(context))
                == .generationFailed
        )
        #expect(
            FoundationModelClientErrorCopy.message(for: .generationFailed)
                .contains("manually")
        )
    }
}
