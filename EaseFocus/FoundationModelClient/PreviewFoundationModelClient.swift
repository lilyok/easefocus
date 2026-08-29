import Foundation

nonisolated struct PreviewFoundationModelClient: FoundationModelGenerating {
    var availability: FoundationModelAvailability = .available

    func currentAvailability(locale: Locale) -> FoundationModelAvailability {
        _ = locale
        return availability
    }

    func generateDraftPlan(survey: GoalSurvey, locale: Locale) async throws -> DraftPlanBlueprint {
        _ = locale

        let availability = currentAvailability(locale: .current)
        guard availability.allowsGeneration else {
            throw FoundationModelClientError.unavailable(availability)
        }

        guard !Task.isCancelled else {
            throw FoundationModelClientError.cancelled
        }

        let goal = survey.trimmedGoal
        let title = goal.isEmpty ? "Learn clearer English pronunciation" : goal
        return DraftPlanBlueprint(
            title: title,
            summary: "A short practice plan you can run in focused sessions.",
            tasks: [
                DraftTaskBlueprint(title: "Record yourself reading a short paragraph", estimatedPomodoros: 1, searchQuery: "beginner English pronunciation exercises"),
                DraftTaskBlueprint(title: "Practice vowel sounds for 20 minutes", estimatedPomodoros: 1, searchQuery: "English vowel sound practice"),
                DraftTaskBlueprint(title: "Repeat a tongue twister slowly", estimatedPomodoros: 1, searchQuery: "easy English tongue twisters"),
            ]
        )
    }
}
