import Foundation
import SwiftData

@Model
final class PlanTask {
    var id: UUID
    var title: String
    var details: String?
    var position: Int
    var estimatedPomodoros: Int
    var status: TaskStatus
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var plan: GoalPlan?

    @Relationship(deleteRule: .cascade, inverse: \FocusSession.task)
    var sessions: [FocusSession]

    init(
        id: UUID = UUID(),
        title: String,
        details: String? = nil,
        position: Int,
        estimatedPomodoros: Int = 1,
        status: TaskStatus = .pending,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        completedAt: Date? = nil,
        sessions: [FocusSession] = []
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.position = position
        self.estimatedPomodoros = max(1, estimatedPomodoros)
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.sessions = sessions
    }

    var completedSessionCount: Int {
        sessions.filter { $0.outcome == .completed }.count
    }

    func markCompleted(at date: Date = .now) {
        status = .completed
        completedAt = date
        updatedAt = date
    }
}
