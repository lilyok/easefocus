import Foundation

nonisolated struct DraftPlanBlueprint: Equatable, Sendable {
    var title: String
    var summary: String
    var tasks: [DraftTaskBlueprint]
}

nonisolated struct DraftTaskBlueprint: Equatable, Sendable {
    var title: String
    var estimatedPomodoros: Int
    var searchQuery: String
}
