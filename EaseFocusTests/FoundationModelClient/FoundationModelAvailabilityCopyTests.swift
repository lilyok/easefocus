import Foundation
import Testing
@testable import EaseFocus

struct FoundationModelAvailabilityCopyTests {
    @Test
    func explainsManualFallbackWhenTheDeviceIsIneligible() {
        let availability = FoundationModelAvailability.unavailable(.deviceNotEligible)

        #expect(FoundationModelAvailabilityCopy.title(for: availability).contains("does not support"))
        #expect(FoundationModelAvailabilityCopy.message(for: availability).contains("manually"))
    }

    @Test
    func previewClientReturnsADeterministicDraft() async throws {
        let client = PreviewFoundationModelClient()

        let draft = try await client.generateDraftPlan(prompt: "anything", locale: Locale(identifier: "en"))

        #expect(draft.tasks.count == 3)
        #expect(client.currentAvailability(locale: Locale(identifier: "en")) == .available)
    }

    @Test
    func mapsClientErrorsOntoExistingAvailabilityCopy() {
        let unavailable = FoundationModelClientError.unavailable(.unavailable(.deviceNotEligible))

        #expect(
            FoundationModelClientErrorCopy.message(for: unavailable)
                == FoundationModelAvailabilityCopy.message(for: .unavailable(.deviceNotEligible))
        )
        #expect(FoundationModelClientErrorCopy.message(for: .validation(.emptyTitle)).contains("not usable"))
        #expect(FoundationModelClientErrorCopy.message(for: .generationFailed).contains("Generation failed"))
    }

    @Test
    func namesTheOutputLanguageInGenerationInstructions() {
        let instructions = DraftPlanPrompt.instructions(locale: Locale(identifier: "es-ES"))

        #expect(instructions.contains("es-ES"))
        #expect(!instructions.contains("the user's language"))
    }
}
