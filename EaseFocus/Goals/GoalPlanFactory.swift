import Foundation

enum GoalPlanFactoryError: Equatable, Error {
    case invalidSearchQuery(index: Int, reason: SearchQueryValidationError)
}

enum GoalPlanFactory {
    static func make(
        title: String,
        details: String?,
        tasks: [(title: String, estimatedPomodoros: Int, searchQuery: String?)],
        source: PlanSource,
        survey: GoalSurvey?,
        locale: Locale,
        now: Date = .now
    ) throws -> GoalPlan {
        let validatedTasks = try tasks.enumerated().map { index, item in
            let result = SearchQueryValidator.validateOptional(item.searchQuery ?? "")
            switch result {
            case .success(let query):
                return (
                    title: item.title,
                    estimatedPomodoros: item.estimatedPomodoros,
                    searchQuery: query
                )
            case .failure(let error):
                throw GoalPlanFactoryError.invalidSearchQuery(index: index, reason: error)
            }
        }
        let plan = GoalPlan(
            title: title,
            details: details,
            createdAt: now,
            updatedAt: now,
            source: source,
            preferredLocaleIdentifier: locale.identifier,
            surveySnapshot: survey?.encoded()
        )
        plan.tasks = validatedTasks.enumerated().map { index, item in
            PlanTask(
                title: item.title,
                position: index,
                estimatedPomodoros: item.estimatedPomodoros,
                createdAt: now,
                updatedAt: now,
                searchQuery: item.searchQuery
            )
        }
        return plan
    }
}
