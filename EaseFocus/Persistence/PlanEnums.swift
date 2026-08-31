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
}

nonisolated enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case active
    case completed
    case archived
}

nonisolated enum RevisionSource: String, Codable, CaseIterable, Sendable {
    case user
    case model
}

nonisolated enum SessionOutcome: String, Codable, CaseIterable, Sendable {
    case completed
    case cancelled
    case interrupted

    var isBroken: Bool {
        self == .cancelled || self == .interrupted
    }

    var progressTitle: String {
        switch self {
        case .completed:
            return "completed"
        case .cancelled, .interrupted:
            return "broken"
        }
    }
}
