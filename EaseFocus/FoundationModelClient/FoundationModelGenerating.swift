import Foundation

nonisolated enum FoundationModelClientError: Equatable, Error {
    case unavailable(FoundationModelAvailability)
    case validation(DraftPlanValidationError)
    case generationFailed
}

nonisolated protocol FoundationModelGenerating: Sendable {
    func currentAvailability(locale: Locale) -> FoundationModelAvailability
    func generateDraftPlan(prompt: String, locale: Locale) async throws -> DraftPlanBlueprint
}
