import Foundation

nonisolated enum PlanRefinementPrompt {
    static func instructions(
        locale: Locale,
        includesResourceSuggestions: Bool
    ) -> String {
        """
        You refine an existing focus plan using typed change sets.
        Output in \(locale.identifier).
        Do not include URLs, domain names, or citations.
        Do not claim you searched the web.
        Never modify, archive, delete, or reorder completed or currently active tasks.
        Never mention or alter focus sessions.
        Task IDs in the prompt are stable UUID strings. Use those exact strings to reference existing pending tasks.
        Identify new tasks with local IDs such as new-1. Never invent a UUID for a new task.
        Include every surviving pending task UUID and every addition local ID exactly once in pendingTaskOrder.
        If you are unsure of order, keep the current pending order and append additions at the end.
        Leave a pending task out of updates to keep it unchanged, but still list it in pendingTaskOrder.
        If the user asks to add a task that already exists with the same or a very similar title, do not add a duplicate.
        Extra project context belongs in a task’s details. Do not rewrite every task or add many tasks from background context.
        The combined number of additions, updates, and archives must be at most \(PlanRefinementLimits.maximumOperationCount).
        When updating a pending task, repeat its existing details unless you are changing them. Leave details empty to keep the current details.
        Do not copy a task title into searchQuery.
        \(DraftPlanPrompt.resourceSearchInstructions(includesResourceSuggestions: includesResourceSuggestions))
        """
    }

    static func completionSummary(for snapshot: PlanSnapshot) -> String {
        let completed = snapshot.tasks.filter { $0.status == .completed }
        let active = snapshot.tasks.filter { $0.status == .active }
        let pending = snapshot.tasks.filter { $0.status == .pending }
        let completedList = completed.map(\.title).joined(separator: "; ")
        let activeList = active.map(\.title).joined(separator: "; ")
        let completedClause = completed.isEmpty
            ? "none"
            : completedList
        let activeClause = active.isEmpty
            ? "none"
            : activeList
        return """
        \(completed.count) of \(snapshot.tasks.count) tasks completed (\(completedClause)). \
        Currently active: \(activeClause). \
        \(pending.count) pending.
        """
    }

    static func userMessage(
        snapshot: PlanSnapshot,
        request: String,
        locale: Locale,
        survey: GoalSurvey?,
        includesResourceSuggestions: Bool
    ) -> String {
        let deadline = survey?.effectiveDeadline.map { date in
            date.formatted(date: .abbreviated, time: .omitted)
        } ?? "none"
        let constraints = survey?.trimmedConstraints.isEmpty == false
            ? survey?.trimmedConstraints ?? "none"
            : "none"
        let success = survey.flatMap { survey in
            survey.trimmedSuccessOutcome.isEmpty ? nil : survey.trimmedSuccessOutcome
        } ?? "not specified"
        let experience = survey?.experience.rawValue ?? "not specified"
        let sessionsPerWeek = survey.map { String($0.sessionsPerWeek) } ?? "not specified"

        return """
        Refine this focus plan.
        Output in \(locale.identifier).
        User request: \(request)
        Experience: \(experience)
        Success looks like: \(success)
        Focus sessions available each week: \(sessionsPerWeek)
        Deadline: \(deadline)
        Constraints: \(constraints)
        Resource search suggestions requested: \(includesResourceSuggestions ? "yes" : "no")
        Completion summary: \(completionSummary(for: snapshot))
        Current plan:
        \(planListing(snapshot))
        If a requested task already exists, do not add another with the same title.
        Put extra context into details on the added or existing task. Do not rewrite the whole plan unless asked.
        pendingTaskOrder must include every remaining pending task UUID and every new local ID.
        Do not include URLs, domain names, or citations.
        Do not include focus-session details.
        \(DraftPlanPrompt.resourceSearchInstructions(includesResourceSuggestions: includesResourceSuggestions))
        """
    }

    static func planListing(_ snapshot: PlanSnapshot) -> String {
        let tasks = snapshot.tasks.sorted { $0.position < $1.position }.map { task in
            let query = collapsed(task.searchQuery)
            let details = collapsed(task.details)
            return """
            - id=\(task.id.uuidString) title=\(task.title) details=\(details) status=\(task.status.rawValue) estimate=\(task.estimatedPomodoros) query=\(query)
            """
        }
        return """
        title=\(snapshot.title)
        details=\(collapsed(snapshot.details))
        status=\(snapshot.status.rawValue)
        \(tasks.joined(separator: "\n"))
        """
    }

    private static func collapsed(_ value: String?) -> String {
        (value ?? "").replacingOccurrences(of: "\n", with: " ")
    }
}
