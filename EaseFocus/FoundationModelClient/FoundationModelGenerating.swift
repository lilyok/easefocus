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
    /// Picks one entry from `candidates` (real attributed quotes). Must not invent text.
    func selectMotivationalQuote(
        taskTitles: [String],
        candidates: [LocalQuote],
        locale: Locale
    ) async throws -> LocalQuote
}
