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
    var searchQuery: String?

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
        sessions: [FocusSession] = [],
        searchQuery: String? = nil
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
        self.searchQuery = searchQuery
    }

    var completedSessionCount: Int {
        sessions.filter { $0.outcome == .completed }.count
    }

    var brokenSessionCount: Int {
        sessions.filter { $0.outcome?.isBroken == true }.count
    }

    func markCompleted(at date: Date = .now) {
        status = .completed
        completedAt = date
        updatedAt = date
    }

    func markPending(at date: Date = .now) {
        status = .pending
        completedAt = nil
        updatedAt = date
    }

    func toggleCompletion(at date: Date = .now) {
        if status == .completed {
            markPending(at: date)
        } else {
            markCompleted(at: date)
        }
    }

    @discardableResult
    func applySearchQuery(_ raw: String, at date: Date = .now) -> Result<String?, SearchQueryValidationError> {
        let result = SearchQueryValidator.validateOptional(raw)
        if case .success(let query) = result {
            searchQuery = query
            updatedAt = date
        }
        return result
    }
}
