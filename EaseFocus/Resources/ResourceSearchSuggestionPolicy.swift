import Foundation

nonisolated enum ResourceSearchSuggestionCopy {
    static let surveyToggle = "Include resource search suggestions"
    static let surveyExplanation = """
    When on, EaseFocus may add optional Google search terms to tasks where they help. These are search suggestions, not links. Nothing is sent to Google during generation or when you save the plan.
    """
    static let addAction = "Add resource search"
    static let removeAction = "Remove"
}

nonisolated enum ResourceSearchControlState: Equatable {
    case hidden
    case addAction
    case editor
}

nonisolated enum ResourceSearchControlPolicy {
    static func draftCreation(
        source: PlanSource,
        includesResourceSuggestions: Bool,
        hasQuery: Bool,
        isAdding: Bool
    ) -> ResourceSearchControlState {
        guard source == .generated, includesResourceSuggestions else {
            return .hidden
        }
        return savedPlan(hasQuery: hasQuery, isAdding: isAdding)
    }

    static func savedPlan(hasQuery: Bool, isAdding: Bool) -> ResourceSearchControlState {
        if hasQuery || isAdding {
            return .editor
        }
        return .addAction
    }

    static func hasQuery(_ raw: String?) -> Bool {
        guard case .success(let query) = SearchQueryValidator.validateOptional(raw ?? "") else {
            return false
        }
        return query != nil
    }
}

nonisolated enum ResourceSearchSuggestionPolicy {
    static func applied(
        to plan: DraftPlanBlueprint,
        includesResourceSuggestions: Bool
    ) -> DraftPlanBlueprint {
        DraftPlanBlueprint(
            title: plan.title,
            summary: plan.summary,
            tasks: plan.tasks.map { task in
                DraftTaskBlueprint(
                    title: task.title,
                    estimatedPomodoros: task.estimatedPomodoros,
                    searchQuery: normalizedQuery(
                        title: task.title,
                        query: task.searchQuery,
                        includesResourceSuggestions: includesResourceSuggestions
                    )
                )
            }
        )
    }

    static func normalizedQuery(
        title: String,
        query: String,
        includesResourceSuggestions: Bool
    ) -> String {
        guard includesResourceSuggestions else {
            return ""
        }
        guard case .success(let validated?) = SearchQueryValidator.validateOptional(query) else {
            return ""
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if validated.compare(trimmedTitle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            return ""
        }
        return validated
    }
}
