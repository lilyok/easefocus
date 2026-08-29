import Foundation
import Testing
@testable import EaseFocus

struct FoundationModelAvailabilityCopyTests {
    @Test
    func tellsTheUserWhereToEnableAppleIntelligence() {
        let availability = FoundationModelAvailability.unavailable(.appleIntelligenceNotEnabled)

        #expect(FoundationModelAvailabilityCopy.title(for: availability).contains("turned off"))
        #expect(FoundationModelAvailabilityCopy.message(for: availability).contains("Apple Intelligence & Siri"))
        #expect(FoundationModelAvailabilityCopy.message(for: availability).contains("survey"))
    }

    @Test
    func explainsManualFallbackWhenTheDeviceIsIneligible() {
        let availability = FoundationModelAvailability.unavailable(.deviceNotEligible)

        #expect(FoundationModelAvailabilityCopy.title(for: availability).contains("does not support"))
        #expect(FoundationModelAvailabilityCopy.message(for: availability).contains("manually"))
    }

    @Test
    func previewClientReturnsADeterministicDraft() async throws {
        var survey = GoalSurvey()
        survey.goal = "Learn clearer English pronunciation"
        let client = PreviewFoundationModelClient()

        let draft = try await client.generateDraftPlan(survey: survey, locale: Locale(identifier: "en"))

        #expect(draft.tasks.count == 3)
        #expect(draft.title == survey.trimmedGoal)
        #expect(client.currentAvailability(locale: Locale(identifier: "en")) == .available)
    }

    @Test
    func mapsClientErrorsOntoExistingAvailabilityCopy() {
        let unavailable = FoundationModelClientError.unavailable(.unavailable(.deviceNotEligible))

        #expect(
            FoundationModelClientErrorCopy.message(for: unavailable)
                == FoundationModelAvailabilityCopy.message(for: .unavailable(.deviceNotEligible))
        )
        #expect(FoundationModelClientErrorCopy.message(for: .validation(.emptyTitle)).contains("missing required titles"))
        #expect(FoundationModelClientErrorCopy.message(for: .validation(.urlLikeContent)).contains("URL"))
        #expect(FoundationModelClientErrorCopy.message(for: .generationFailed).contains("Generation failed"))
    }
}
