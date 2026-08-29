import Foundation

nonisolated enum FoundationModelAvailability: Equatable, Sendable {
    case available
    case unavailable(UnavailableReason)
    case localeUnsupported(Locale)

    nonisolated enum UnavailableReason: Equatable, Sendable {
        case deviceNotEligible
        case appleIntelligenceNotEnabled
        case modelNotReady
        case unknown
    }

    var allowsGeneration: Bool {
        self == .available
    }

    var showsPlanSurvey: Bool {
        switch self {
        case .unavailable(.deviceNotEligible):
            false
        default:
            true
        }
    }

    var canOpenAppleIntelligenceSettings: Bool {
        switch self {
        case .unavailable(.appleIntelligenceNotEnabled), .unavailable(.modelNotReady):
            true
        default:
            false
        }
    }
}

nonisolated enum FoundationModelAvailabilityCopy {
    static func title(for availability: FoundationModelAvailability) -> String {
        switch availability {
        case .available:
            return "Apple Intelligence is available"
        case .unavailable(.deviceNotEligible):
            return "This device does not support Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is turned off"
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still downloading"
        case .unavailable(.unknown):
            return "Apple Intelligence is unavailable"
        case .localeUnsupported:
            return "This language is not supported for generation"
        }
    }

    static func message(for availability: FoundationModelAvailability) -> String {
        switch availability {
        case .available:
            return "Generated plans stay on this device. You can still create a plan manually."
        case .unavailable(.deviceNotEligible):
            return "You can still create goals and tasks manually, and run the focus timer."
        case .unavailable(.appleIntelligenceNotEnabled):
            #if os(macOS)
            return "Turn it on in System Settings → Apple Intelligence & Siri if you want a generated plan from a short survey. Manual planning still works."
            #else
            return "Turn it on in Settings → Apple Intelligence & Siri if you want a generated plan from a short survey. Manual planning still works."
            #endif
        case .unavailable(.modelNotReady):
            return "Wait for the model to finish downloading in Apple Intelligence & Siri, or create a plan manually."
        case .unavailable(.unknown):
            return "You can still create a plan manually and use the timer."
        case .localeUnsupported:
            return "Choose a supported language for generation, or create a plan manually."
        }
    }
}

nonisolated enum FoundationModelClientErrorCopy {
    static func message(for error: FoundationModelClientError) -> String {
        switch error {
        case .unavailable(let availability):
            return FoundationModelAvailabilityCopy.message(for: availability)
        case .validation(let reason):
            return validationMessage(for: reason)
        case .refusal:
            return "Apple Intelligence declined this request. Rephrase the goal or create the plan manually."
        case .guardrailViolation:
            return "Apple Intelligence blocked this request for safety. Adjust the goal or create the plan manually."
        case .unsupportedLanguageOrLocale:
            return "Apple Intelligence cannot generate a plan in this language. Choose a supported language or create the plan manually."
        case .contextLimitExceeded:
            return "The request is too long for Apple Intelligence. Shorten the goal or constraints, then try again—or create the plan manually."
        case .generationFailed:
            return "Generation failed. You can still create a plan manually."
        case .cancelled:
            return ""
        }
    }

    static func validationMessage(for error: DraftPlanValidationError) -> String {
        switch error {
        case .emptyTitle, .emptyTaskTitle, .noTasks:
            return "The generated draft was missing required titles. You can generate again or create a plan manually."
        case .tooManyTasks:
            return "The generated draft had too many tasks. You can generate again or create a plan manually."
        case .duplicateTask:
            return "The generated draft repeated a task. You can generate again or create a plan manually."
        case .invalidPomodoroEstimate:
            return "The generated draft had an invalid session estimate. You can generate again or create a plan manually."
        case .urlLikeContent:
            return "The generated draft included a URL. You can generate again or create a plan manually."
        case .invalidSearchQuery(let error):
            return "\(SearchQueryValidationCopy.message(for: error)) You can edit the generated draft or create a plan manually."
        }
    }
}
