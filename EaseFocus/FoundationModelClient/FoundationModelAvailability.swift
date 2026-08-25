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
            return "Turn on Apple Intelligence in Settings if you want generated plans. Manual planning still works."
        case .unavailable(.modelNotReady):
            return "Wait for the model to finish downloading, or create a plan manually."
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
        case .validation:
            return "The generated draft was not usable. You can still create a plan manually."
        case .generationFailed:
            return "Generation failed. You can still create a plan manually."
        }
    }
}
