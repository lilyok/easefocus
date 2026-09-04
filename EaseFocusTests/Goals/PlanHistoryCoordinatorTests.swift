import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct PlanHistoryCoordinatorTests {
    private enum SampleError: Error {
        case diskFull
    }

    @Test
    @MainActor
    func requestingUndoOrStartOverDoesNotMutateSwiftData() throws {
        let (plan, context, container) = try makePlanWithRevision()
        _ = container
        let before = PlanSnapshot.capturing(plan)
        let coordinator = PlanHistoryCoordinator()

        coordinator.requestUndo(plan: plan, isSessionRunningOnPlan: false)
        #expect(coordinator.isUndoConfirmPresented)
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.orderedRevisions.count == 1)

        coordinator.discardUndo()
        coordinator.confirmUndo(plan: plan, context: context, isSessionRunningOnPlan: false)
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.orderedRevisions.count == 1)

        coordinator.requestStartOver(isSessionRunningOnPlan: false)
        #expect(coordinator.isStartOverConfirmPresented)
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.orderedRevisions.count == 1)
    }

    @Test
    @MainActor
    func confirmUndoRestoresThePlanAfterTheConfirmedPath() throws {
        let (plan, context, container) = try makePlanWithRevision()
        _ = container
        let coordinator = PlanHistoryCoordinator()
        coordinator.requestUndo(plan: plan, isSessionRunningOnPlan: false)
        #expect(coordinator.isUndoConfirmPresented)

        coordinator.confirmUndo(plan: plan, context: context, isSessionRunningOnPlan: false)

        #expect(coordinator.didApply)
        #expect(!coordinator.isUndoConfirmPresented)
        #expect(plan.orderedTasks.first?.title == "Practice hola")
        #expect(plan.orderedRevisions.count == 2)
        #expect(plan.orderedRevisions.last?.reason == PlanHistoryCopy.undoReason)
    }

    @Test
    @MainActor
    func confirmStartOverRequiresTheConfirmedPath() throws {
        let (plan, context, container) = try makePlanWithRevision()
        _ = container
        let coordinator = PlanHistoryCoordinator()

        coordinator.confirmStartOver(plan: plan, context: context, isSessionRunningOnPlan: false)

        #expect(!coordinator.didApply)
        #expect(plan.orderedTasks.first?.status == .pending)
        #expect(plan.orderedRevisions.count == 1)

        coordinator.requestStartOver(isSessionRunningOnPlan: false)
        coordinator.confirmStartOver(plan: plan, context: context, isSessionRunningOnPlan: false)

        #expect(coordinator.didApply)
        #expect(plan.orderedTasks.first?.status == .archived)
        #expect(plan.orderedRevisions.last?.reason == PlanHistoryCopy.startOverReason)
        #expect(plan.surveySnapshot != nil)
    }

    @Test
    @MainActor
    func saveFailureSurfacesRetryAndDiscardWithoutASecondRollback() throws {
        let (plan, context, container) = try makePlanWithRevision()
        _ = container
        let before = PlanSnapshot.capturing(plan)
        let coordinator = PlanHistoryCoordinator()
        var remainingFailures = 1
        let save: (ModelContext) throws -> Void = { context in
            if remainingFailures > 0 {
                remainingFailures -= 1
                throw SampleError.diskFull
            }
            try context.save()
        }

        coordinator.requestUndo(plan: plan, isSessionRunningOnPlan: false)
        coordinator.confirmUndo(
            plan: plan,
            context: context,
            isSessionRunningOnPlan: false,
            save: save
        )

        #expect(!coordinator.didApply)
        #expect(coordinator.isSaveAlertPresented)
        #expect(coordinator.saveErrorMessage == PersistenceSaveCopy.message)
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.orderedRevisions.count == 1)

        coordinator.discardFailedSave()
        #expect(!coordinator.isSaveAlertPresented)
        #expect(PlanSnapshot.capturing(plan) == before)

        coordinator.requestUndo(plan: plan, isSessionRunningOnPlan: false)
        coordinator.confirmUndo(
            plan: plan,
            context: context,
            isSessionRunningOnPlan: false,
            save: save
        )
        #expect(coordinator.didApply)
        #expect(plan.orderedRevisions.count == 2)
    }

    @Test
    @MainActor
    func retrySaveReappliesAfterAFailedStartOver() throws {
        let (plan, context, container) = try makePlanWithRevision()
        _ = container
        let coordinator = PlanHistoryCoordinator()
        var remainingFailures = 1
        let save: (ModelContext) throws -> Void = { context in
            if remainingFailures > 0 {
                remainingFailures -= 1
                throw SampleError.diskFull
            }
            try context.save()
        }

        coordinator.requestStartOver(isSessionRunningOnPlan: false)
        coordinator.confirmStartOver(
            plan: plan,
            context: context,
            isSessionRunningOnPlan: false,
            save: save
        )
        #expect(coordinator.isSaveAlertPresented)
        #expect(plan.orderedTasks.first?.status == .pending)

        coordinator.retrySave()
        #expect(coordinator.didApply)
        #expect(plan.orderedTasks.first?.status == .archived)
    }

    @Test
    @MainActor
    func requestingUndoWhileASessionIsRunningDoesNotMutateSwiftData() throws {
        let (plan, _, container) = try makePlanWithRevision()
        _ = container
        let before = PlanSnapshot.capturing(plan)
        let coordinator = PlanHistoryCoordinator()

        coordinator.requestUndo(plan: plan, isSessionRunningOnPlan: true)

        #expect(!coordinator.isUndoConfirmPresented)
        #expect(coordinator.actionError == PlanHistoryCopy.sessionRunning)
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.orderedRevisions.count == 1)
    }

    @MainActor
    private func makePlanWithRevision() throws -> (GoalPlan, ModelContext, ModelContainer) {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let survey = GoalSurvey(goal: "Learn Spanish greetings")
        let pending = PlanTask(title: "Practice hola", position: 0)
        let completed = PlanTask(title: "Record a greeting", position: 1, status: .completed)
        let plan = GoalPlan(
            title: "Spanish greetings",
            surveySnapshot: survey.encoded(),
            tasks: [pending, completed]
        )
        context.insert(plan)
        try context.save()

        let before = PlanSnapshot.capturing(plan)
        pending.title = "Practice hola and adios"
        let after = PlanSnapshot.capturing(plan)
        let revision = try PlanRevisionFactory.make(
            for: plan,
            reason: "Rename pending work",
            source: .model,
            changeSummary: "Renamed a pending task",
            before: before,
            after: after
        )
        context.insert(revision)
        try context.save()
        return (plan, context, container)
    }
}
