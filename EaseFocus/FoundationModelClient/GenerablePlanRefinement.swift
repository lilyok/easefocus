import Foundation
import FoundationModels

@Generable
nonisolated struct GenerablePlanRefinement {
    @Guide(description: "A short summary of the proposed changes, with no URLs")
    var changeSummary: String

    @Guide(description: "New pending tasks to add. Leave empty if none. Identify each addition with a local ID such as new-1. Never invent a UUID.", .count(0...6))
    var additions: [GenerableTaskAddition]

    @Guide(description: "Full replacements of existing pending tasks only. Use the task UUID string. Never reference completed or active tasks.", .count(0...8))
    var updates: [GenerableTaskUpdate]

    @Guide(description: "UUID strings of pending tasks to archive. Never archive completed or active tasks.", .count(0...8))
    var archivedTaskIDs: [String]

    @Guide(description: "Final order of surviving pending task UUID strings and addition local IDs. Include every remaining pending task and every addition exactly once. Never include completed or active tasks.")
    var pendingTaskOrder: [String]
}

@Generable
nonisolated struct GenerableTaskAddition {
    @Guide(description: "A local identifier for this new task, such as new-1. Do not use a UUID.")
    var localID: String

    @Guide(description: "A concrete achievable task title with no URLs")
    var title: String

    @Guide(description: "Optional short details with no URLs. Leave empty if none.")
    var details: String

    @Guide(description: "Estimated Pomodoro sessions from 1 to 8", .range(1...8))
    var estimatedPomodoros: Int

    @Guide(description: "Leave empty unless a generic task-specific search query adds clear value. No URLs, domain names, names, deadlines, constraints, or copies of the task title")
    var searchQuery: String
}

@Generable
nonisolated struct GenerableTaskUpdate {
    @Guide(description: "The existing pending task UUID string. Never reference completed or active tasks.")
    var taskID: String

    @Guide(description: "The updated task title with no URLs")
    var title: String

    @Guide(description: "Optional short details with no URLs. Leave empty to clear details.")
    var details: String

    @Guide(description: "Estimated Pomodoro sessions from 1 to 8", .range(1...8))
    var estimatedPomodoros: Int

    @Guide(description: "Updated search query, or empty to remove it when resource suggestions are enabled")
    var searchQuery: String
}

extension PlanRefinementProposal {
    nonisolated init(_ generated: GenerablePlanRefinement) {
        self.init(
            changeSummary: generated.changeSummary,
            additions: generated.additions.map { addition in
                PlanRefinementAddition(
                    localID: addition.localID,
                    title: addition.title,
                    details: addition.details,
                    estimatedPomodoros: addition.estimatedPomodoros,
                    searchQuery: addition.searchQuery
                )
            },
            updates: generated.updates.map { update in
                PlanRefinementUpdate(
                    taskID: update.taskID,
                    title: update.title,
                    details: update.details,
                    estimatedPomodoros: update.estimatedPomodoros,
                    searchQuery: update.searchQuery
                )
            },
            archivedTaskIDs: generated.archivedTaskIDs,
            pendingTaskOrder: generated.pendingTaskOrder
        )
    }
}
