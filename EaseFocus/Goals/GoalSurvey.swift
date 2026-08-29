import Foundation

nonisolated enum ExperienceLevel: String, Codable, CaseIterable, Sendable {
    case beginner
    case someExperience
    case advanced

    var title: String {
        switch self {
        case .beginner:
            return "Beginner"
        case .someExperience:
            return "Some experience"
        case .advanced:
            return "Advanced"
        }
    }
}

nonisolated struct GoalSurvey: Equatable, Codable, Sendable {
    var goal = ""
    var experience: ExperienceLevel = .beginner
    var successOutcome = ""
    var sessionsPerWeek = 4
    var hasDeadline = false
    var deadline = Date.now
    var constraints = ""

    static let sessionsPerWeekRange = 1...14

    var trimmedGoal: String {
        goal.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSuccessOutcome: String {
        successOutcome.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedConstraints: String {
        constraints.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveDeadline: Date? {
        hasDeadline ? deadline : nil
    }

    var isReadyToGenerate: Bool {
        !trimmedGoal.isEmpty
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data?) -> GoalSurvey? {
        guard let data else {
            return nil
        }
        return try? JSONDecoder().decode(GoalSurvey.self, from: data)
    }
}
