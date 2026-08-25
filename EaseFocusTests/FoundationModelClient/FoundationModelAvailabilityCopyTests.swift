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
}
