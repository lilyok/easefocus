import Foundation
import SwiftData

enum TaskInbox {
    static func plan(from plans: [GoalPlan], in context: ModelContext, locale: Locale) -> GoalPlan {
        if let existing = plans.first(where: { $0.status == .active }) {
            return existing
        }
        let plan = GoalPlan(
            title: PomodoroCopy.inboxTitle.localized(locale),
            source: .manual,
            preferredLocaleIdentifier: locale.identifier
        )
        context.insert(plan)
        return plan
    }
}
