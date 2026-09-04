import Foundation
import SwiftData

nonisolated enum PlanHistoryUndoAvailability: Equatable, Sendable {
    case available
    case noRevision
    case stale
    case sessionRunning
    case malformed
}

nonisolated struct PlanHistoryRevisionRecord: Equatable, Sendable {
    var id: UUID
    var createdAt: Date
    var reason: String
    var changeSummary: String
    var source: RevisionSource
}

nonisolated struct PlanHistoryItem: Equatable, Identifiable, Sendable {
    var id: UUID
    var createdAt: Date
    var reason: String
    var changeSummary: String
    var source: RevisionSource
    var isNewest: Bool
}

nonisolated enum PlanHistoryPresentation {
    static func showsHistory(revisionCount: Int) -> Bool {
        revisionCount > 0
    }

    static func displayedRevisions(_ orderedOldestFirst: [PlanHistoryRevisionRecord]) -> [PlanHistoryItem] {
        let newestFirst = Array(orderedOldestFirst.reversed())
        return newestFirst.enumerated().map { index, revision in
            PlanHistoryItem(
                id: revision.id,
                createdAt: revision.createdAt,
                reason: revision.reason,
                changeSummary: revision.changeSummary,
                source: revision.source,
                isNewest: index == 0
            )
        }
    }

    static func sourceLabel(for source: RevisionSource) -> String {
        PlanHistoryCopy.sourceLabel(for: source)
    }

    static func isSessionRunning(
        planTaskIDs: Set<UUID>,
        hasActiveTask: Bool,
        timerTaskID: UUID?,
        timerPhase: FocusTimerPhase
    ) -> Bool {
        if hasActiveTask {
            return true
        }
        guard timerPhase != .idle else {
            return false
        }
        if let timerTaskID {
            return planTaskIDs.contains(timerTaskID)
        }
        switch timerPhase {
        case .runningBreak, .pausedBreak, .completed:
            return true
        case .idle, .runningFocus, .pausedFocus:
            return false
        }
    }

    static func undoAvailability(
        current: PlanSnapshot?,
        lastAfter: PlanSnapshot?,
        isSessionRunningOnPlan: Bool
    ) -> PlanHistoryUndoAvailability {
        if isSessionRunningOnPlan {
            return .sessionRunning
        }
        guard let current, let lastAfter else {
            return lastAfter == nil && current != nil ? .noRevision : .malformed
        }
        return current == lastAfter ? .available : .stale
    }

    static func canStartOver(isSessionRunningOnPlan: Bool) -> Bool {
        !isSessionRunningOnPlan
    }

    static func restoredSnapshot(current: PlanSnapshot, target: PlanSnapshot) throws -> PlanSnapshot {
        let currentByID = Dictionary(uniqueKeysWithValues: current.tasks.map { ($0.id, $0) })
        var restored: [TaskSnapshot] = []
        var seen = Set<UUID>()

        for task in target.tasks.sorted(by: { $0.position < $1.position }) {
            if let live = currentByID[task.id], isProtected(live) {
                restored.append(live)
            } else {
                restored.append(task)
            }
            seen.insert(task.id)
        }

        for live in current.tasks.sorted(by: { $0.position < $1.position }) where isProtected(live) && !seen.contains(live.id) {
            restored.append(live)
            seen.insert(live.id)
        }

        for index in restored.indices {
            restored[index].position = index
        }

        return try PlanSnapshot(
            id: current.id,
            title: target.title,
            details: target.details,
            status: current.status,
            tasks: restored
        ).validated()
    }

    static func startOverSnapshot(current: PlanSnapshot) throws -> PlanSnapshot {
        let tasks = current.tasks
            .sorted { $0.position < $1.position }
            .enumerated()
            .map { index, task in
                var copy = task
                copy.position = index
                if task.status == .pending {
                    copy.status = .archived
                }
                return copy
            }
        return try PlanSnapshot(
            id: current.id,
            title: current.title,
            details: current.details,
            status: current.status,
            tasks: tasks
        ).validated()
    }

    static func decodedSnapshots(before: Data, after: Data) -> (before: PlanSnapshot, after: PlanSnapshot)? {
        do {
            return (
                try PlanSnapshotCoding.decode(before).validated(),
                try PlanSnapshotCoding.decode(after).validated()
            )
        } catch {
            return nil
        }
    }

    private static func isProtected(_ task: TaskSnapshot) -> Bool {
        task.status == .completed || task.status == .active
    }
}

nonisolated enum PlanHistoryAccessibilityIdentifier {
    static let history = "planHistory"
    static let undo = "undoLastRevision"
    static let confirmUndo = "confirmUndoRevision"
    static let discardUndo = "discardUndoRevision"
    static let startOver = "startOverPlan"
    static let confirmStartOver = "confirmStartOver"
    static let cancelStartOver = "cancelStartOver"
}

nonisolated enum PlanHistoryCopy {
    static let historyTitle = "History"
    static let revisionTitle = "Revision"
    static let undoAction = "Undo last"
    static let undoConfirmTitle = "Undo this change?"
    static let undoConfirmMessage = "The plan will go back to the state before this change. Completed tasks and focus sessions stay."
    static let confirmUndo = "Confirm undo"
    static let discardUndo = "Keep plan"
    static let startOverAction = "Start over"
    static let startOverConfirmTitle = "Start over?"
    static let startOverConfirmMessage = "Pending work will be cleared. Completed tasks and focus sessions will stay. You can add tasks manually or use Refine after this."
    static let confirmStartOver = "Start over"
    static let cancelStartOver = "Cancel"
    static let staleUndo = "The plan changed after this revision, so Undo last is unavailable. History is still readable."
    static let sessionRunning = "Finish or cancel the timer on this plan before Undo last or Start over."
    static let noRevision = "There is no revision to undo."
    static let malformed = "Couldn't read this revision. History is still available for other entries."
    static let undoReason = "Undo last change"
    static let startOverReason = "Start over"
    static let startOverSummary = "Cleared pending work. Completed tasks and focus sessions stayed."
    static let unreadableRevision = "Couldn't read this revision's snapshots."

    static func sourceLabel(for source: RevisionSource) -> String {
        switch source {
        case .user:
            return "You"
        case .model:
            return "Apple Intelligence"
        }
    }

    static func undoSummary(restoringReason: String) -> String {
        "Restored the plan to the state before “\(restoringReason)”."
    }

    static func message(for availability: PlanHistoryUndoAvailability) -> String? {
        switch availability {
        case .available:
            return nil
        case .noRevision:
            return noRevision
        case .stale:
            return staleUndo
        case .sessionRunning:
            return sessionRunning
        case .malformed:
            return malformed
        }
    }
}
