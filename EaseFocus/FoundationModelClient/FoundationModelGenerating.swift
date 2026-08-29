import Foundation

nonisolated enum FoundationModelClientError: Equatable, Error {
    case unavailable(FoundationModelAvailability)
    case validation(DraftPlanValidationError)
    case refusal
    case guardrailViolation
    case unsupportedLanguageOrLocale
    case contextLimitExceeded
    case generationFailed
    case cancelled
}

nonisolated protocol FoundationModelGenerating: Sendable {
    func currentAvailability(locale: Locale) -> FoundationModelAvailability
    func generateDraftPlan(survey: GoalSurvey, locale: Locale) async throws -> DraftPlanBlueprint
}
