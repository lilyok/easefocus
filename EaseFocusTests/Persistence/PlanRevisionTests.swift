import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct PlanRevisionTests {
    @Test
    @MainActor
    func recordsBeforeAndAfterSnapshotsWithoutMutatingThePlan() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let planID = UUID()
        let pending = PlanTask(title: "Practice hola", position: 0, searchQuery: "Spanish greetings audio")
        let completed = PlanTask(title: "Record a greeting", position: 1, status: .completed)
        let session = FocusSession(plannedDurationSeconds: 1_500, elapsedSeconds: 1_200, outcome: .completed)
        completed.sessions = [session]
        let plan = GoalPlan(id: planID, title: "Spanish greetings", tasks: [pending, completed])
        context.insert(plan)
        try context.save()

        let before = PlanSnapshot.capturing(plan)
        pending.title = "Practice hola and adios"
        let after = PlanSnapshot.capturing(plan)

        let revision = try PlanRevisionFactory.make(
            for: plan,
            reason: "Add speaking detail",
            source: .user,
            changeSummary: "Renamed a pending task",
            before: before,
            after: after
        )
        context.insert(revision)
        try context.save()

        #expect(plan.title == "Spanish greetings")
        #expect(plan.orderedTasks.map(\.title) == ["Practice hola and adios", "Record a greeting"])
        #expect(completed.sessions.count == 1)
        #expect(plan.orderedRevisions.map(\.reason) == ["Add speaking detail"])
        #expect(try revision.decodedBeforeSnapshot().tasks.first?.title == "Practice hola")
        #expect(try revision.decodedAfterSnapshot().tasks.first?.title == "Practice hola and adios")
        #expect(try revision.decodedBeforeSnapshot().id == planID)
        #expect(try revision.decodedAfterSnapshot().id == planID)
    }

    @Test
    @MainActor
    func keepsRevisionsInCreatedOrder() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let plan = GoalPlan(title: "Plan")
        let task = PlanTask(title: "Task", position: 0)
        plan.tasks = [task]
        context.insert(plan)

        let snapshot = PlanSnapshot.capturing(plan)
        let first = try PlanRevisionFactory.make(
            for: plan,
            reason: "First",
            source: .user,
            changeSummary: "First change",
            before: snapshot,
            after: snapshot,
            now: Date(timeIntervalSince1970: 1)
        )
        let second = try PlanRevisionFactory.make(
            for: plan,
            reason: "Second",
            source: .model,
            changeSummary: "Second change",
            before: snapshot,
            after: snapshot,
            now: Date(timeIntervalSince1970: 2)
        )
        context.insert(first)
        context.insert(second)
        try context.save()

        #expect(plan.orderedRevisions.map(\.reason) == ["First", "Second"])
        #expect(plan.orderedRevisions.map(\.source) == [.user, .model])
    }

    @Test
    @MainActor
    func rejectsEmptyReasonsAndSnapshotsThatDoNotMatchThePlan() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let plan = GoalPlan(title: "Plan")
        container.mainContext.insert(plan)
        let snapshot = PlanSnapshot.capturing(plan)
        var other = snapshot
        other.id = UUID()

        #expect(throws: PlanRevisionFactoryError.emptyReason) {
            _ = try PlanRevisionFactory.make(
                for: plan,
                reason: "   ",
                source: .user,
                changeSummary: "Nope",
                before: snapshot,
                after: snapshot
            )
        }
        #expect(throws: PlanRevisionFactoryError.malformedSnapshot) {
            _ = try PlanRevisionFactory.make(
                for: plan,
                reason: "Refine",
                source: .user,
                changeSummary: "Wrong plan",
                before: other,
                after: snapshot
            )
        }
    }

    @Test
    @MainActor
    func rejectsDeletingOrRewritingCompletedTasks() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let completedID = UUID()
        let pending = PlanTask(title: "Practice hola", position: 0)
        let completed = PlanTask(id: completedID, title: "Record a greeting", position: 1, status: .completed)
        let plan = GoalPlan(title: "Spanish greetings", tasks: [pending, completed])
        container.mainContext.insert(plan)
        let before = PlanSnapshot.capturing(plan)

        var deleted = before
        deleted.tasks = [TaskSnapshot.capturing(pending)]
        #expect(throws: PlanRevisionFactoryError.completedWorkMutated) {
            _ = try PlanRevisionFactory.make(
                for: plan,
                reason: "Drop completed work",
                source: .model,
                changeSummary: "Deleted a completed task",
                before: before,
                after: deleted
            )
        }

        var rewritten = before
        rewritten.tasks = before.tasks.map { task in
            guard task.id == completedID else {
                return task
            }
            var mutated = task
            mutated.title = "Rewrite completed work"
            return mutated
        }
        #expect(throws: PlanRevisionFactoryError.completedWorkMutated) {
            _ = try PlanRevisionFactory.make(
                for: plan,
                reason: "Rewrite completed work",
                source: .model,
                changeSummary: "Changed a completed task",
                before: before,
                after: rewritten
            )
        }
    }

    @Test
    @MainActor
    func deletingAPlanCascadesItsRevisionsAndLeavesOtherPlans() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let kept = GoalPlan(title: "Keep")
        let removed = GoalPlan(title: "Remove")
        let task = PlanTask(title: "Task", position: 0)
        removed.tasks = [task]
        context.insert(kept)
        context.insert(removed)
        let snapshot = PlanSnapshot.capturing(removed)
        let revision = try PlanRevisionFactory.make(
            for: removed,
            reason: "History",
            source: .user,
            changeSummary: "Will cascade",
            before: snapshot,
            after: snapshot
        )
        context.insert(revision)
        try context.save()

        context.delete(removed)
        try context.save()

        let remainingPlans = try context.fetch(FetchDescriptor<GoalPlan>())
        let remainingRevisions = try context.fetch(FetchDescriptor<PlanRevision>())
        #expect(remainingPlans.map(\.title) == ["Keep"])
        #expect(remainingRevisions.isEmpty)
    }
}
