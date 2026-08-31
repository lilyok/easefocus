import Foundation

nonisolated enum PlanRefinementValidationError: Equatable, Error {
    case emptyRequest
    case requestTooLong
    case emptyChangeSummary
    case emptyTaskTitle
    case textTooLong
    case urlLikeContent
    case malformedTaskID
    case unknownTaskID
    case protectedTaskReferenced
    case duplicateOperation
    case conflictingOperations
    case missingFromOrdering
    case duplicateInOrdering
    case invalidPomodoroEstimate
    case invalidSearchQuery(SearchQueryValidationError)
    case searchQueryCopiesTitle
    case resourceQueryWhenDisabled
    case tooManyTasks
    case tooManyOperations
    case noChanges
    case malformedSnapshot
}

nonisolated enum PlanRefinementLimits {
    static let maximumRequestLength = 500
    static let maximumSummaryLength = 280
    static let maximumTitleLength = DraftPlanValidator.maximumTitleLength
    static let maximumDetailsLength = 280
    static let maximumLocalIDLength = 32
    static let maximumOperationCount = 8
    static let maximumTaskCount = DraftPlanValidator.maximumTaskCount
    static let maximumPendingOrderCount = 16
    static let pomodoroRange = DraftPlanValidator.pomodoroRange
}

nonisolated struct PlanRefinementProposal: Equatable, Sendable {
    var changeSummary: String
    var additions: [PlanRefinementAddition]
    var updates: [PlanRefinementUpdate]
    var archivedTaskIDs: [String]
    var pendingTaskOrder: [String]
}

nonisolated struct PlanRefinementAddition: Equatable, Sendable {
    var localID: String
    var title: String
    var details: String
    var estimatedPomodoros: Int
    var searchQuery: String
}

nonisolated struct PlanRefinementUpdate: Equatable, Sendable {
    var taskID: String
    var title: String
    var details: String
    var estimatedPomodoros: Int
    var searchQuery: String
}

nonisolated struct PlanRefinementPreview: Equatable, Sendable {
    var request: String
    var changeSummary: String
    var before: PlanSnapshot
    var after: PlanSnapshot
}
