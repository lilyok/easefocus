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
    var includesResourceSuggestions = false

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

    enum CodingKeys: String, CodingKey {
        case goal
        case experience
        case successOutcome
        case sessionsPerWeek
        case hasDeadline
        case deadline
        case constraints
        case includesResourceSuggestions
    }

    init(
        goal: String = "",
        experience: ExperienceLevel = .beginner,
        successOutcome: String = "",
        sessionsPerWeek: Int = 4,
        hasDeadline: Bool = false,
        deadline: Date = Date.now,
        constraints: String = "",
        includesResourceSuggestions: Bool = false
    ) {
        self.goal = goal
        self.experience = experience
        self.successOutcome = successOutcome
        self.sessionsPerWeek = sessionsPerWeek
        self.hasDeadline = hasDeadline
        self.deadline = deadline
        self.constraints = constraints
        self.includesResourceSuggestions = includesResourceSuggestions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goal = try container.decode(String.self, forKey: .goal)
        experience = try container.decode(ExperienceLevel.self, forKey: .experience)
        successOutcome = try container.decode(String.self, forKey: .successOutcome)
        sessionsPerWeek = try container.decode(Int.self, forKey: .sessionsPerWeek)
        hasDeadline = try container.decode(Bool.self, forKey: .hasDeadline)
        deadline = try container.decode(Date.self, forKey: .deadline)
        constraints = try container.decode(String.self, forKey: .constraints)
        includesResourceSuggestions = try container.decodeIfPresent(
            Bool.self,
            forKey: .includesResourceSuggestions
        ) ?? false
    }
}
