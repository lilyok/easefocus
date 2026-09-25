import Foundation
import SwiftData

enum TaskInbox {
    /// Plan used for the + Add task button: always the local "My tasks" inbox,
    /// not whichever generated plan happens to be active.
    static func plan(from plans: [GoalPlan], in context: ModelContext, locale: Locale) -> GoalPlan {
        inbox(from: plans, in: context, locale: locale)
    }

    static func inbox(from plans: [GoalPlan], in context: ModelContext, locale: Locale) -> GoalPlan {
        plan(named: PomodoroCopy.inboxTitle.localized(locale), from: plans, in: context, locale: locale)
    }

    /// Find or create a plan whose title matches `title` (case-insensitive).
    /// Empty titles resolve to the inbox.
    static func plan(
        named title: String,
        from plans: [GoalPlan],
        in context: ModelContext,
        locale: Locale
    ) -> GoalPlan {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = trimmed.isEmpty
            ? PomodoroCopy.inboxTitle.localized(locale)
            : trimmed
        if let existing = plans.first(where: {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(target) == .orderedSame
        }) {
            return existing
        }
        let plan = GoalPlan(
            title: target,
            source: .manual,
            preferredLocaleIdentifier: locale.identifier
        )
        context.insert(plan)
        return plan
    }

    /// Move `task` onto the plan named `title`, creating that plan if needed.
    /// Other tasks on the previous plan keep their tag.
    static func retag(
        _ task: PlanTask,
        to title: String,
        from plans: [GoalPlan],
        in context: ModelContext,
        locale: Locale,
        at date: Date = .now
    ) {
        let destination = plan(named: title, from: plans, in: context, locale: locale)
        guard task.plan?.id != destination.id else {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = trimmed.isEmpty
                ? PomodoroCopy.inboxTitle.localized(locale)
                : trimmed
            if task.plan?.title != resolved {
                task.plan?.title = resolved
                task.plan?.updatedAt = date
                task.updatedAt = date
            }
            return
        }
        if let previous = task.plan {
            previous.tasks.removeAll { $0.id == task.id }
            previous.updatedAt = date
        }
        destination.insertTaskAtFront(task, at: date)
    }
}
