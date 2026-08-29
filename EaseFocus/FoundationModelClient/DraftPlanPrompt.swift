import Foundation

nonisolated enum DraftPlanPrompt {
    static func instructions(locale: Locale) -> String {
        """
        You create short, concrete focus plans.
        Output in \(locale.identifier).
        Do not include URLs, domain names, or citations.
        Do not claim you searched the web.
        Tasks must be achievable and specific.
        Do not replace or mention completed work.
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
        Keep the number of tasks and estimated sessions appropriate for \(survey.sessionsPerWeek) sessions per week.
        Do not include URLs, domain names, or citations.
        """
    }
}
