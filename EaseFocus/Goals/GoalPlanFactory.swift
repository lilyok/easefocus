import Foundation

enum GoalPlanFactory {
    static func make(
        title: String,
        details: String?,
        tasks: [(title: String, estimatedPomodoros: Int, searchQuery: String)],
        source: PlanSource,
        survey: GoalSurvey?,
        locale: Locale,
        now: Date = .now
    ) -> GoalPlan {
        let plan = GoalPlan(
            title: title,
            details: details,
            createdAt: now,
            updatedAt: now,
            source: source,
            preferredLocaleIdentifier: locale.identifier,
            surveySnapshot: survey?.encoded()
        )
        plan.tasks = tasks.enumerated().map { index, item in
            PlanTask(
                title: item.title,
                position: index,
                estimatedPomodoros: item.estimatedPomodoros,
                createdAt: now,
                updatedAt: now,
                searchQuery: item.searchQuery.nilIfEmpty
            )
        }
        return plan
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
