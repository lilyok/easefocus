import Foundation

nonisolated enum DraftPlanPrompt {
    static func instructions(
        locale: Locale,
        includesResourceSuggestions: Bool
    ) -> String {
        """
        You create short, concrete focus plans.
        Output in \(locale.identifier).
        Do not include URLs, domain names, or citations.
        Do not claim you searched the web.
        Tasks must be achievable and specific.
        Do not replace or mention completed work.
        \(resourceSearchInstructions(includesResourceSuggestions: includesResourceSuggestions))
        """
    }

    static func userMessage(for survey: GoalSurvey) -> String {
        let deadline = survey.effectiveDeadline.map { date in
            date.formatted(date: .abbreviated, time: .omitted)
        } ?? "none"
        let constraints = survey.trimmedConstraints.isEmpty ? "none" : survey.trimmedConstraints
        let success = survey.trimmedSuccessOutcome.isEmpty ? "not specified" : survey.trimmedSuccessOutcome

        return """
        Create a focus plan for this goal.
        Goal: \(survey.trimmedGoal)
        Experience: \(survey.experience.rawValue)
        Success looks like: \(success)
        Focus sessions available each week: \(survey.sessionsPerWeek)
        Deadline: \(deadline)
        Constraints: \(constraints)
        Resource search suggestions requested: \(survey.includesResourceSuggestions ? "yes" : "no")
        Keep the number of tasks and estimated sessions appropriate for \(survey.sessionsPerWeek) sessions per week.
        Do not include URLs, domain names, or citations.
        \(resourceSearchInstructions(includesResourceSuggestions: survey.includesResourceSuggestions))
        """
    }

    static func resourceSearchInstructions(includesResourceSuggestions: Bool) -> String {
        if includesResourceSuggestions {
            return """
            Add a searchQuery only for a task where a resource search would provide clear value.
            Leave searchQuery empty for every other task. A query is optional and must never be required.
            Search queries must be generic, task-specific, and not copies of the task title.
            Do not copy names or other personal survey details into a searchQuery, including deadlines and constraints.
            Search queries must contain no URLs or domain names.
            Do not claim you searched the web.
            """
        }

        return """
        Do not generate resource search suggestions.
        Every searchQuery must be empty.
        """
    }
}
