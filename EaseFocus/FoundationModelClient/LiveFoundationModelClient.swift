import Foundation
import FoundationModels

nonisolated struct LiveFoundationModelClient: FoundationModelGenerating {
    func currentAvailability(locale: Locale) -> FoundationModelAvailability {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            if model.supportsLocale(locale) {
                return .available
            }
            return .localeUnsupported(locale)
        case .unavailable(.deviceNotEligible):
            return .unavailable(.deviceNotEligible)
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable(.appleIntelligenceNotEnabled)
        case .unavailable(.modelNotReady):
            return .unavailable(.modelNotReady)
        case .unavailable:
            return .unavailable(.unknown)
        @unknown default:
            return .unavailable(.unknown)
        }
    }

    func generateDraftPlan(prompt: String, locale: Locale) async throws -> DraftPlanBlueprint {
        let availability = currentAvailability(locale: locale)
        guard availability.allowsGeneration else {
            throw FoundationModelClientError.unavailable(availability)
        }

        let session = LanguageModelSession {
            DraftPlanPrompt.instructions(locale: locale)
        }

        let generated: GenerableDraftPlan
        do {
            generated = try await session.respond(
                to: prompt,
                generating: GenerableDraftPlan.self
            ).content
        } catch let error as FoundationModelClientError {
            throw error
        } catch {
            throw FoundationModelClientError.generationFailed
        }

        let blueprint = DraftPlanBlueprint(
            title: generated.title,
            summary: generated.summary,
            tasks: generated.tasks.map { task in
                DraftTaskBlueprint(
                    title: task.title,
                    estimatedPomodoros: task.estimatedPomodoros,
                    searchQuery: task.searchQuery
                )
            }
        )

        switch DraftPlanValidator.validate(blueprint) {
        case .success(let validated):
            return validated
        case .failure(let error):
            throw FoundationModelClientError.validation(error)
        }
    }
}

@Generable
nonisolated struct GenerableDraftPlan {
    @Guide(description: "A short concrete plan title with no URLs")
    var title: String

    @Guide(description: "A one-sentence summary with no URLs")
    var summary: String

    @Guide(description: "Between 3 and 6 concrete tasks", .count(3...6))
    var tasks: [GenerableDraftTask]
}

@Generable
nonisolated struct GenerableDraftTask {
    @Guide(description: "A concrete achievable task title with no URLs")
    var title: String

    @Guide(description: "Estimated Pomodoro sessions from 1 to 8", .range(1...8))
    var estimatedPomodoros: Int

    @Guide(description: "A short web search query with no URLs or domain names")
    var searchQuery: String
}
