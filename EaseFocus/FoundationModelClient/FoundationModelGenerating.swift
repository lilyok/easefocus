import Foundation

nonisolated enum FoundationModelClientError: Equatable, Error {
    case unavailable(FoundationModelAvailability)
    case validation(DraftPlanValidationError)
    case generationFailed
    case cancelled
}

nonisolated protocol FoundationModelGenerating: Sendable {
    func currentAvailability(locale: Locale) -> FoundationModelAvailability
    func generateDraftPlan(survey: GoalSurvey, locale: Locale) async throws -> DraftPlanBlueprint
}
