import Foundation

nonisolated struct PreviewFoundationModelClient: FoundationModelGenerating {
    var availability: FoundationModelAvailability = .available

    func currentAvailability(locale: Locale) -> FoundationModelAvailability {
        _ = locale
        return availability
    }

    func generateDraftPlan(prompt: String, locale: Locale) async throws -> DraftPlanBlueprint {
        _ = prompt
        _ = locale

        let availability = currentAvailability(locale: .current)
        guard availability.allowsGeneration else {
            throw FoundationModelClientError.unavailable(availability)
        }

        return DraftPlanBlueprint(
            title: "Learn clearer English pronunciation",
            summary: "A short practice plan you can run in focused sessions.",
            tasks: [
                DraftTaskBlueprint(title: "Record yourself reading a short paragraph", estimatedPomodoros: 1, searchQuery: "beginner English pronunciation exercises"),
                DraftTaskBlueprint(title: "Practice vowel sounds for 20 minutes", estimatedPomodoros: 1, searchQuery: "English vowel sound practice"),
                DraftTaskBlueprint(title: "Repeat a tongue twister slowly", estimatedPomodoros: 1, searchQuery: "easy English tongue twisters"),
            ]
        )
    }
}
