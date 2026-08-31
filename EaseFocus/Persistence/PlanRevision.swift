import Foundation
import SwiftData

@Model
final class PlanRevision {
    var id: UUID
    var createdAt: Date
    var reason: String
    var source: RevisionSource
    var changeSummary: String
    var beforeSnapshotData: Data
    var afterSnapshotData: Data
    var plan: GoalPlan?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        reason: String,
        source: RevisionSource,
        changeSummary: String,
        beforeSnapshotData: Data,
        afterSnapshotData: Data
    ) {
        self.id = id
        self.createdAt = createdAt
        self.reason = reason
        self.source = source
        self.changeSummary = changeSummary
        self.beforeSnapshotData = beforeSnapshotData
        self.afterSnapshotData = afterSnapshotData
    }
}
