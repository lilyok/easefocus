import Foundation
import SwiftData

/// Placeholder SwiftData model for Phase 0 scaffolding only.
///
/// Phase 1 replaces this with `GoalPlan`, `PlanTask`, and `FocusSession`.
/// Do not evolve this type into product data.
///
/// EaseFocus keeps the old App Store bundle ID (`lil.pomodoro`) so it can
/// update the existing listing. Runtime Core Data migration from the old
/// Pomodoro store is intentionally omitted for the first release.
@Model
final class FocusItem {
    var createdAt: Date

    init(createdAt: Date = .now) {
        self.createdAt = createdAt
    }
}
