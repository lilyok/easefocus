import Foundation

nonisolated enum PlanStatus: String, Codable, CaseIterable, Sendable {
    case active
    case paused
    case completed
    case archived
}

nonisolated enum PlanSource: String, Codable, CaseIterable, Sendable {
    case manual
    case generated
    case imported
}

nonisolated enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case active
    case completed
    case archived
}

nonisolated enum SessionOutcome: String, Codable, CaseIterable, Sendable {
    case completed
    case cancelled
    case interrupted
}
