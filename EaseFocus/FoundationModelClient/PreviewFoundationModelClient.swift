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
        let suggestedQueries = [
            "beginner English pronunciation exercises",
            "English vowel sound practice",
            "easy English tongue twisters",
        ]
        let tasks = [
            ("Record yourself reading a short paragraph", 1),
            ("Practice vowel sounds for 20 minutes", 1),
            ("Repeat a tongue twister slowly", 1),
        ].enumerated().map { index, item in
            DraftTaskBlueprint(
                title: item.0,
                estimatedPomodoros: item.1,
                searchQuery: suggestedQueries[index]
            )
        }
        return ResourceSearchSuggestionPolicy.applied(
            to: DraftPlanBlueprint(
                title: title,
                summary: "A short practice plan you can run in focused sessions.",
                tasks: tasks
            ),
            includesResourceSuggestions: survey.includesResourceSuggestions
        )
    }
}
