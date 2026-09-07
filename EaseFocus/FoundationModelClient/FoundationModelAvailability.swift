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
    static func title(for availability: FoundationModelAvailability) -> LocalizedCopy {
        switch availability {
        case .available:
            return LocalizedCopy("Apple Intelligence is available")
        case .unavailable(.deviceNotEligible):
            return LocalizedCopy("This device does not support Apple Intelligence")
        case .unavailable(.appleIntelligenceNotEnabled):
            return LocalizedCopy("Apple Intelligence is turned off")
        case .unavailable(.modelNotReady):
            return LocalizedCopy("Apple Intelligence is still downloading")
        case .unavailable(.unknown):
            return LocalizedCopy("Apple Intelligence is unavailable")
        case .localeUnsupported:
            return LocalizedCopy("This language is not supported for generation")
        }
    }

    static func message(for availability: FoundationModelAvailability) -> LocalizedCopy {
        switch availability {
        case .available:
            return LocalizedCopy(
                "Generated plans stay on this device. You can still create a plan manually."
            )
        case .unavailable(.deviceNotEligible):
            return LocalizedCopy(
                "You can still create goals and tasks manually, and run the focus timer."
            )
        case .unavailable(.appleIntelligenceNotEnabled):
            #if os(macOS)
            return LocalizedCopy(
                "Turn it on in System Settings → Apple Intelligence & Siri if you want a generated plan from a short survey. Manual planning still works."
            )
            #else
            return LocalizedCopy(
                "Turn it on in Settings → Apple Intelligence & Siri if you want a generated plan from a short survey. Manual planning still works."
            )
            #endif
        case .unavailable(.modelNotReady):
            return LocalizedCopy(
                "Wait for the model to finish downloading in Apple Intelligence & Siri, or create a plan manually."
            )
        case .unavailable(.unknown):
            return LocalizedCopy("You can still create a plan manually and use the timer.")
        case .localeUnsupported:
            return LocalizedCopy(
                "Choose a supported language for generation, or create a plan manually."
            )
        }
    }
}

nonisolated enum FoundationModelClientErrorCopy {
    static func message(for error: FoundationModelClientError) -> LocalizedCopy {
        switch error {
        case .unavailable(let availability):
            return FoundationModelAvailabilityCopy.message(for: availability)
        case .validation(let reason):
            return validationMessage(for: reason)
        case .refusal:
            return LocalizedCopy(
                "Apple Intelligence declined this request. Rephrase the goal or create the plan manually."
            )
        case .guardrailViolation:
            return LocalizedCopy(
                "Apple Intelligence blocked this request for safety. Adjust the goal or create the plan manually."
            )
        case .unsupportedLanguageOrLocale:
            return LocalizedCopy(
                "Apple Intelligence cannot generate a plan in this language. Choose a supported language or create the plan manually."
            )
        case .contextLimitExceeded:
            return LocalizedCopy(
                "The request is too long for Apple Intelligence. Shorten the goal or constraints, then try again—or create the plan manually."
            )
        case .generationFailed:
            return LocalizedCopy("Generation failed. You can still create a plan manually.")
        case .cancelled:
            return LocalizedCopy("")
        }
    }

    static func validationMessage(for error: DraftPlanValidationError) -> LocalizedCopy {
        switch error {
        case .emptyTitle, .emptyTaskTitle, .noTasks:
            return LocalizedCopy(
                "The generated draft was missing required titles. You can generate again or create a plan manually."
            )
        case .tooManyTasks:
            return LocalizedCopy(
                "The generated draft had too many tasks. You can generate again or create a plan manually."
            )
        case .duplicateTask:
            return LocalizedCopy(
                "The generated draft repeated a task. You can generate again or create a plan manually."
            )
        case .invalidPomodoroEstimate:
            return LocalizedCopy(
                "The generated draft had an invalid session estimate. You can generate again or create a plan manually."
            )
        case .urlLikeContent:
            return LocalizedCopy(
                "The generated draft included a URL. You can generate again or create a plan manually."
            )
        case .invalidSearchQuery:
            return LocalizedCopy(
                "The generated draft included an invalid search query. You can edit the generated draft or create a plan manually."
            )
        }
    }
}
