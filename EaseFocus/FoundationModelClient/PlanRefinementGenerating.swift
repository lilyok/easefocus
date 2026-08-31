import Foundation

nonisolated enum PlanRefinementGenerationError: Equatable, Error {
    case unavailable(FoundationModelAvailability)
    case validation(PlanRefinementValidationError)
    case refusal
    case guardrailViolation
    case unsupportedLanguageOrLocale
    case contextLimitExceeded
    case generationFailed
    case cancelled
}

nonisolated protocol PlanRefinementGenerating: Sendable {
    func currentAvailability(locale: Locale) -> FoundationModelAvailability
    func generateRefinementPreview(
        snapshot: PlanSnapshot,
        request: String,
        locale: Locale,
        survey: GoalSurvey?,
        includesResourceSuggestions: Bool
    ) async throws -> PlanRefinementPreview
}

extension PlanRefinementGenerationError {
    static func from(_ error: FoundationModelClientError) -> PlanRefinementGenerationError {
        switch error {
        case .unavailable(let availability):
            return .unavailable(availability)
        case .validation:
            return .generationFailed
        case .refusal:
            return .refusal
        case .guardrailViolation:
            return .guardrailViolation
        case .unsupportedLanguageOrLocale:
            return .unsupportedLanguageOrLocale
        case .contextLimitExceeded:
            return .contextLimitExceeded
        case .generationFailed:
            return .generationFailed
        case .cancelled:
            return .cancelled
        }
    }
}
