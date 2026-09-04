import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct PlanHistoryApplierTests {
    private enum SampleError: Error {
        case diskFull
    }

    @Test
    @MainActor
    func undoAppliesOnlyWhenCurrentMatchesLastAfterAndRecordsANewRevision() throws {
        let (plan, pending, completed, sessionID, context, _, container) = try makePlanWithRevision()
        _ = container
        let beforeUndo = PlanSnapshot.capturing(plan)
        #expect(plan.orderedTasks.contains { $0.title == "Practice hola and adios" })

        try PlanHistoryApplier.undoLast(
            on: plan,
            in: context,
            isSessionRunningOnPlan: false,
            now: Date(timeIntervalSince1970: 99)
        )

        #expect(plan.orderedTasks.map(\.title) == ["Practice hola", "Record a greeting"])
        #expect(plan.orderedTasks.first?.id == pending.id)
        #expect(completed.sessions.map(\.id) == [sessionID])
        #expect(completed.status == .completed)
        #expect(plan.orderedRevisions.count == 2)
        #expect(plan.orderedRevisions.last?.source == .user)
        #expect(plan.orderedRevisions.last?.reason == PlanHistoryCopy.undoReason)
        #expect(try plan.orderedRevisions.last?.decodedBeforeSnapshot() == beforeUndo)
        #expect(try plan.orderedRevisions.last?.decodedAfterSnapshot().tasks.first?.title == "Practice hola")
        #expect(plan.orderedRevisions.first?.reason == "Rename pending work")
        #expect(plan.surveySnapshot != nil)
    }

    @Test
    @MainActor
    func undoIsBlockedWhenThePlanHasDiverged() throws {
        let (plan, pending, completed, sessionID, context, _, container) = try makePlanWithRevision()
        _ = container
        pending.title = "Edited after revision"
        try context.save()
        let before = PlanSnapshot.capturing(plan)

        #expect(throws: PlanHistoryApplierError.stale) {
            try PlanHistoryApplier.undoLast(on: plan, in: context, isSessionRunningOnPlan: false)
        }
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.orderedRevisions.count == 1)
        #expect(completed.sessions.map(\.id) == [sessionID])
    }

    @Test
    @MainActor
    func undoIsBlockedWhileASessionIsRunning() throws {
        let (plan, _, completed, sessionID, context, _, container) = try makePlanWithRevision()
        _ = container
        let before = PlanSnapshot.capturing(plan)

        #expect(throws: PlanHistoryApplierError.sessionRunning) {
            try PlanHistoryApplier.undoLast(on: plan, in: context, isSessionRunningOnPlan: true)
        }
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.orderedRevisions.count == 1)
        #expect(completed.sessions.map(\.id) == [sessionID])
    }

    @Test
    @MainActor
    func undoSaveFailureLeavesThePlanUnchanged() throws {
        let (plan, _, completed, sessionID, context, _, container) = try makePlanWithRevision()
        _ = container
        let before = PlanSnapshot.capturing(plan)

        #expect(throws: PlanHistoryApplierError.saveFailed) {
            try PlanHistoryApplier.undoLast(
                on: plan,
                in: context,
                isSessionRunningOnPlan: false,
                save: { _ in throw SampleError.diskFull }
            )
        }
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.orderedRevisions.count == 1)
        #expect(completed.sessions.map(\.id) == [sessionID])
    }

    @Test
    @MainActor
    func undoRemovesPendingTasksAddedByTheLastRevision() throws {
        let (plan, pending, completed, sessionID, context, _, container) = try makePlanWithRevision()
        _ = container
        let beforeAdding = PlanSnapshot.capturing(plan)
        let added = PlanTask(title: "Shadow a dialogue", position: 2)
        added.plan = plan
        plan.tasks.append(added)
        plan.updatedAt = Date(timeIntervalSince1970: 80)
        let afterAdding = PlanSnapshot.capturing(plan)
        let addedRevision = try PlanRevisionFactory.make(
            for: plan,
            reason: "Add a speaking drill",
            source: .model,
            changeSummary: "Added a pending task",
            before: beforeAdding,
            after: afterAdding,
            now: Date(timeIntervalSince1970: 80)
        )
        context.insert(addedRevision)
        try context.save()

        try PlanHistoryApplier.undoLast(
            on: plan,
            in: context,
            isSessionRunningOnPlan: false,
            now: Date(timeIntervalSince1970: 99)
        )

        #expect(plan.orderedTasks.map(\.id) == [pending.id, completed.id])
        #expect(!plan.orderedTasks.contains { $0.id == added.id })
        #expect(completed.sessions.map(\.id) == [sessionID])
        #expect(plan.orderedRevisions.count == 3)
        #expect(plan.orderedRevisions.last?.reason == PlanHistoryCopy.undoReason)
        #expect(plan.orderedRevisions.map(\.reason).contains("Add a speaking drill"))
    }

    @Test
    @MainActor
    func startOverArchivesPendingWorkPreservesCompletedSessionsAndRecordsARevision() throws {
        let (plan, pending, completed, sessionID, context, surveyData, container) = try makePlanWithRevision()
        _ = container
        try PlanHistoryApplier.startOver(
            on: plan,
            in: context,
            isSessionRunningOnPlan: false,
            now: Date(timeIntervalSince1970: 120)
        )

        #expect(pending.status == .archived)
        #expect(completed.status == .completed)
        #expect(completed.sessions.map(\.id) == [sessionID])
        #expect(plan.surveySnapshot == surveyData)
        #expect(plan.orderedRevisions.count == 2)
        #expect(plan.orderedRevisions.last?.source == .user)
        #expect(plan.orderedRevisions.last?.reason == PlanHistoryCopy.startOverReason)
        #expect(plan.orderedRevisions.last?.changeSummary == PlanHistoryCopy.startOverSummary)
        #expect(try plan.orderedRevisions.last?.decodedAfterSnapshot().tasks.first { $0.id == pending.id }?.status == .archived)
    }

    @Test
    @MainActor
    func startOverIsBlockedWhileASessionIsRunning() throws {
        let (plan, pending, _, _, context, _, container) = try makePlanWithRevision()
        _ = container
        #expect(throws: PlanHistoryApplierError.sessionRunning) {
            try PlanHistoryApplier.startOver(on: plan, in: context, isSessionRunningOnPlan: true)
        }
        #expect(pending.status == .pending)
        #expect(plan.orderedRevisions.count == 1)
    }

    @Test
    @MainActor
    func startOverSaveFailureLeavesThePlanUnchanged() throws {
        let (plan, pending, completed, sessionID, context, _, container) = try makePlanWithRevision()
        _ = container
        let before = PlanSnapshot.capturing(plan)
        #expect(throws: PlanHistoryApplierError.saveFailed) {
            try PlanHistoryApplier.startOver(
                on: plan,
                in: context,
                isSessionRunningOnPlan: false,
                save: { _ in throw SampleError.diskFull }
            )
        }
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(pending.status == .pending)
        #expect(completed.sessions.map(\.id) == [sessionID])
        #expect(plan.orderedRevisions.count == 1)
    }

    @Test
    @MainActor
    func startOverRecordsARevisionWhenThePlanHasNoHistory() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let pending = PlanTask(title: "Practice hola", position: 0)
        let completed = PlanTask(title: "Record a greeting", position: 1, status: .completed)
        let sessionID = UUID()
        completed.sessions = [
            FocusSession(
                id: sessionID,
                plannedDurationSeconds: 1_500,
                elapsedSeconds: 1_200,
                outcome: .completed
            )
        ]
        let plan = GoalPlan(
            title: "Spanish greetings",
            surveySnapshot: GoalSurvey(goal: "Learn Spanish greetings").encoded(),
            tasks: [pending, completed]
        )
        context.insert(plan)
        try context.save()

        try PlanHistoryApplier.startOver(on: plan, in: context, isSessionRunningOnPlan: false)

        #expect(pending.status == .archived)
        #expect(completed.status == .completed)
        #expect(completed.sessions.map(\.id) == [sessionID])
        #expect(plan.orderedRevisions.count == 1)
        #expect(plan.orderedRevisions.last?.source == .user)
        #expect(plan.orderedRevisions.last?.reason == PlanHistoryCopy.startOverReason)
        #expect(plan.surveySnapshot != nil)
    }

    @MainActor
    private func makePlanWithRevision() throws -> (
        GoalPlan,
        PlanTask,
        PlanTask,
        UUID,
        ModelContext,
        Data?,
        ModelContainer
    ) {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        var survey = GoalSurvey(goal: "Learn Spanish greetings")
        survey.includesResourceSuggestions = false
        let surveyData = survey.encoded()
        let pending = PlanTask(title: "Practice hola", position: 0)
        let completed = PlanTask(title: "Record a greeting", position: 1, status: .completed)
        let sessionID = UUID()
        let session = FocusSession(
            id: sessionID,
            plannedDurationSeconds: 1_500,
            elapsedSeconds: 1_200,
            outcome: .completed
        )
        completed.sessions = [session]
        let plan = GoalPlan(
            title: "Spanish greetings",
            details: "A short speaking plan.",
            surveySnapshot: surveyData,
            tasks: [pending, completed]
        )
        context.insert(plan)
        try context.save()

        let before = PlanSnapshot.capturing(plan)
        pending.title = "Practice hola and adios"
        plan.updatedAt = Date(timeIntervalSince1970: 50)
        let after = PlanSnapshot.capturing(plan)
        let revision = try PlanRevisionFactory.make(
            for: plan,
            reason: "Rename pending work",
            source: .model,
            changeSummary: "Renamed a pending task",
            before: before,
            after: after,
            now: Date(timeIntervalSince1970: 50)
        )
        context.insert(revision)
        try context.save()
        return (plan, pending, completed, sessionID, context, surveyData, container)
    }
}
