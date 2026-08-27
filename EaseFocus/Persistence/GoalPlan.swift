import Foundation
import SwiftData

@Model
final class GoalPlan {
    var id: UUID
    var title: String
    var details: String?
    var createdAt: Date
    var updatedAt: Date
    var status: PlanStatus
    var source: PlanSource
    var preferredLocaleIdentifier: String
    var surveySnapshot: Data?

    @Relationship(deleteRule: .cascade, inverse: \PlanTask.plan)
    var tasks: [PlanTask]

    init(
        id: UUID = UUID(),
        title: String,
        details: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        status: PlanStatus = .active,
        source: PlanSource = .manual,
        preferredLocaleIdentifier: String = Locale.current.identifier,
        surveySnapshot: Data? = nil,
        tasks: [PlanTask] = []
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.source = source
        self.preferredLocaleIdentifier = preferredLocaleIdentifier
        self.surveySnapshot = surveySnapshot
        self.tasks = tasks
    }

    var orderedTasks: [PlanTask] {
        tasks.sorted { $0.position < $1.position }
    }

    var pendingTasks: [PlanTask] {
        orderedTasks.filter { $0.status == .pending || $0.status == .active }
    }
}
