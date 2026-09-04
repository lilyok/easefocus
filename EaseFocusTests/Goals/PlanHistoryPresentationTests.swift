import Foundation
import Testing
@testable import EaseFocus

struct PlanHistoryPresentationTests {
    private let pendingID = UUID(uuidString: "00000000-0000-4000-8000-00000000000a")!
    private let completedID = UUID(uuidString: "00000000-0000-4000-8000-00000000000d")!
    private let addedID = UUID(uuidString: "00000000-0000-4000-8000-00000000add1")!
    private let planID = UUID(uuidString: "00000000-0000-4000-8000-00000000aaaa")!

    @Test
    func hidesHistoryWhenThereAreNoRevisions() {
        #expect(!PlanHistoryPresentation.showsHistory(revisionCount: 0))
        #expect(PlanHistoryPresentation.showsHistory(revisionCount: 1))
    }

    @Test
    func listsRevisionsNewestFirstAndMarksTheLatest() {
        let older = PlanHistoryRevisionRecord(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            createdAt: Date(timeIntervalSince1970: 1),
            reason: "First",
            changeSummary: "First change",
            source: .user
        )
        let newer = PlanHistoryRevisionRecord(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
            createdAt: Date(timeIntervalSince1970: 2),
            reason: "Second",
            changeSummary: "Second change",
            source: .model
        )
        let items = PlanHistoryPresentation.displayedRevisions([older, newer])
        #expect(items.map(\.reason) == ["Second", "First"])
        #expect(items.map(\.isNewest) == [true, false])
        #expect(items.first?.source == .model)
        #expect(PlanHistoryCopy.sourceLabel(for: .user) == "You")
        #expect(PlanHistoryCopy.sourceLabel(for: .model) == "Apple Intelligence")
    }

    @Test
    func decodesRevisionSnapshotsForReadOnlyHistory() throws {
        let snapshot = mixedSnapshot()
        let encoded = try PlanSnapshotCoding.encode(snapshot)
        let decoded = try #require(PlanHistoryPresentation.decodedSnapshots(before: encoded, after: encoded))
        #expect(decoded.before == snapshot)
        #expect(decoded.after == snapshot)
        #expect(PlanHistoryPresentation.decodedSnapshots(before: Data("nope".utf8), after: encoded) == nil)
    }

    @Test
    func undoIsAvailableOnlyWhenCurrentMatchesLastAfterAndNoSessionIsRunning() {
        let snapshot = mixedSnapshot()
        #expect(
            PlanHistoryPresentation.undoAvailability(
                current: snapshot,
                lastAfter: snapshot,
                isSessionRunningOnPlan: false
            ) == .available
        )
        var edited = snapshot
        edited.tasks[0].title = "Edited after revision"
        #expect(
            PlanHistoryPresentation.undoAvailability(
                current: edited,
                lastAfter: snapshot,
                isSessionRunningOnPlan: false
            ) == .stale
        )
        #expect(
            PlanHistoryPresentation.undoAvailability(
                current: snapshot,
                lastAfter: snapshot,
                isSessionRunningOnPlan: true
            ) == .sessionRunning
        )
        #expect(
            PlanHistoryPresentation.undoAvailability(
                current: snapshot,
                lastAfter: nil,
                isSessionRunningOnPlan: false
            ) == .noRevision
        )
        #expect(PlanHistoryCopy.message(for: .stale) == PlanHistoryCopy.staleUndo)
        #expect(PlanHistoryCopy.message(for: .sessionRunning) == PlanHistoryCopy.sessionRunning)
    }

    @Test
    func startOverIsBlockedWhileASessionIsRunning() {
        #expect(PlanHistoryPresentation.canStartOver(isSessionRunningOnPlan: false))
        #expect(!PlanHistoryPresentation.canStartOver(isSessionRunningOnPlan: true))
    }

    @Test
    func treatsAnActiveTaskOrNonIdleTimerOnThePlanAsARunningSession() {
        #expect(
            PlanHistoryPresentation.isSessionRunning(
                planTaskIDs: [pendingID],
                hasActiveTask: true,
                timerTaskID: nil,
                timerPhase: .idle
            )
        )
        #expect(
            PlanHistoryPresentation.isSessionRunning(
                planTaskIDs: [pendingID],
                hasActiveTask: false,
                timerTaskID: pendingID,
                timerPhase: .runningFocus
            )
        )
        #expect(
            PlanHistoryPresentation.isSessionRunning(
                planTaskIDs: [pendingID],
                hasActiveTask: false,
                timerTaskID: pendingID,
                timerPhase: .pausedFocus
            )
        )
        #expect(
            PlanHistoryPresentation.isSessionRunning(
                planTaskIDs: [pendingID],
                hasActiveTask: false,
                timerTaskID: pendingID,
                timerPhase: .completed
            )
        )
        #expect(
            PlanHistoryPresentation.isSessionRunning(
                planTaskIDs: [pendingID],
                hasActiveTask: false,
                timerTaskID: pendingID,
                timerPhase: .runningBreak
            )
        )
        #expect(
            PlanHistoryPresentation.isSessionRunning(
                planTaskIDs: [pendingID],
                hasActiveTask: false,
                timerTaskID: pendingID,
                timerPhase: .pausedBreak
            )
        )
        #expect(
            PlanHistoryPresentation.isSessionRunning(
                planTaskIDs: [pendingID],
                hasActiveTask: false,
                timerTaskID: nil,
                timerPhase: .runningBreak
            )
        )
        #expect(
            !PlanHistoryPresentation.isSessionRunning(
                planTaskIDs: [pendingID],
                hasActiveTask: false,
                timerTaskID: UUID(),
                timerPhase: .runningFocus
            )
        )
        #expect(
            !PlanHistoryPresentation.isSessionRunning(
                planTaskIDs: [pendingID],
                hasActiveTask: false,
                timerTaskID: UUID(),
                timerPhase: .runningBreak
            )
        )
    }

    @Test
    func restoredSnapshotRevertsPendingWorkAndKeepsProtectedTasks() throws {
        let current = mixedSnapshot(pendingTitle: "Practice hola and adios", includingAdded: true)
        let target = mixedSnapshot()
        let restored = try PlanHistoryPresentation.restoredSnapshot(current: current, target: target)
        #expect(restored.title == target.title)
        #expect(restored.tasks.map(\.id) == [pendingID, completedID])
        #expect(restored.tasks.first?.title == "Practice hola")
        #expect(restored.tasks.last?.status == .completed)
        #expect(restored.tasks.last?.title == "Record a greeting")
        #expect(!restored.tasks.contains { $0.id == addedID })
    }

    @Test
    func startOverSnapshotArchivesPendingTasksAndLeavesCompletedWork() throws {
        let current = mixedSnapshot(includingAdded: true)
        let after = try PlanHistoryPresentation.startOverSnapshot(current: current)
        let byID = Dictionary(uniqueKeysWithValues: after.tasks.map { ($0.id, $0) })
        #expect(byID[pendingID]?.status == .archived)
        #expect(byID[addedID]?.status == .archived)
        #expect(byID[completedID]?.status == .completed)
        #expect(byID[completedID]?.title == "Record a greeting")
        #expect(after.title == current.title)
        #expect(after.details == current.details)
    }

    @Test
    func usesTheSameChangeKindsAsRefinePlanForHistoryDiffs() throws {
        let before = mixedSnapshot()
        var after = mixedSnapshot(pendingTitle: "Practice hola and adios", includingAdded: true)
        after.tasks = after.tasks.map { task in
            guard task.id == pendingID else {
                return task
            }
            var updated = task
            updated.status = .archived
            return updated
        }
        let displayed = PlanRefinementPresentation.displayedTasks(before: before, after: after)
        let byID = Dictionary(uniqueKeysWithValues: displayed.map { ($0.id, $0) })
        #expect(byID[addedID]?.kind == .added)
        #expect(byID[pendingID]?.kind == .archived)
        #expect(byID[completedID]?.kind == .protected)
    }

    @Test
    func exposesHistoryAccessibilityIdentifiers() {
        #expect(PlanHistoryAccessibilityIdentifier.history == "planHistory")
        #expect(PlanHistoryAccessibilityIdentifier.undo == "undoLastRevision")
        #expect(PlanHistoryAccessibilityIdentifier.confirmUndo == "confirmUndoRevision")
        #expect(PlanHistoryAccessibilityIdentifier.discardUndo == "discardUndoRevision")
        #expect(PlanHistoryAccessibilityIdentifier.startOver == "startOverPlan")
        #expect(PlanHistoryAccessibilityIdentifier.confirmStartOver == "confirmStartOver")
        #expect(PlanHistoryAccessibilityIdentifier.cancelStartOver == "cancelStartOver")
    }

    private func mixedSnapshot(
        pendingTitle: String = "Practice hola",
        includingAdded: Bool = false
    ) -> PlanSnapshot {
        var tasks = [
            TaskSnapshot(
                id: pendingID,
                title: pendingTitle,
                details: nil,
                position: 0,
                estimatedPomodoros: 1,
                status: .pending,
                searchQuery: nil
            ),
            TaskSnapshot(
                id: completedID,
                title: "Record a greeting",
                details: nil,
                position: 1,
                estimatedPomodoros: 1,
                status: .completed,
                searchQuery: nil
            ),
        ]
        if includingAdded {
            tasks.append(
                TaskSnapshot(
                    id: addedID,
                    title: "Shadow a dialogue",
                    details: nil,
                    position: 2,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: nil
                )
            )
        }
        return PlanSnapshot(
            id: planID,
            title: "Spanish greetings",
            details: "A short speaking plan.",
            status: .active,
            tasks: tasks
        )
    }
}
