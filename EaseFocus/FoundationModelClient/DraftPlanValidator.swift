import Foundation

nonisolated enum DraftPlanValidationError: Equatable, Error {
    case emptyTitle
    case emptyTaskTitle
    case noTasks
    case tooManyTasks
    case duplicateTask
    case invalidPomodoroEstimate
    case urlLikeContent
}

nonisolated enum DraftPlanValidator {
    static let maximumTitleLength = 80
    static let maximumTaskCount = 8
    static let pomodoroRange = 1...8

    static func validate(_ plan: DraftPlanBlueprint) -> Result<DraftPlanBlueprint, DraftPlanValidationError> {
        let title = clamp(plan.title, maxLength: maximumTitleLength)
        guard !title.isEmpty else {
            return .failure(.emptyTitle)
        }

        guard !containsURLLikeContent(title) && !containsURLLikeContent(plan.summary) else {
            return .failure(.urlLikeContent)
        }

        guard !plan.tasks.isEmpty else {
            return .failure(.noTasks)
        }

        guard plan.tasks.count <= maximumTaskCount else {
            return .failure(.tooManyTasks)
        }

        var seenTitles = Set<String>()
        var tasks: [DraftTaskBlueprint] = []

        for task in plan.tasks {
            let taskTitle = clamp(task.title, maxLength: maximumTitleLength)
            guard !taskTitle.isEmpty else {
                return .failure(.emptyTaskTitle)
            }
            guard !containsURLLikeContent(taskTitle) && !containsURLLikeContent(task.searchQuery) else {
                return .failure(.urlLikeContent)
            }
            let normalizedTitle = taskTitle.lowercased()
            guard seenTitles.insert(normalizedTitle).inserted else {
                return .failure(.duplicateTask)
            }
            guard pomodoroRange.contains(task.estimatedPomodoros) else {
                return .failure(.invalidPomodoroEstimate)
            }

            tasks.append(
                DraftTaskBlueprint(
                    title: taskTitle,
                    estimatedPomodoros: task.estimatedPomodoros,
                    searchQuery: task.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }

        return .success(
            DraftPlanBlueprint(
                title: title,
                summary: clamp(plan.summary, maxLength: 280),
                tasks: tasks
            )
        )
    }

    private static func clamp(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else {
            return trimmed
        }
        return String(trimmed.prefix(maxLength))
    }

    private static func containsURLLikeContent(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("http://")
            || lowered.contains("https://")
            || lowered.contains("www.")
    }
}
