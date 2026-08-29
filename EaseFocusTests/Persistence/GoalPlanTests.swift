import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct GoalPlanTests {
    @Test
    @MainActor
    func keepsTaskOrderAndStableIDs() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let firstID = UUID()
        let plan = GoalPlan(title: "Spanish greetings")
        let first = PlanTask(id: firstID, title: "Practice hola", position: 0)
        let second = PlanTask(title: "Record a greeting", position: 1, estimatedPomodoros: 2)
        plan.tasks = [second, first]
        context.insert(plan)

        #expect(plan.orderedTasks.map(\.title) == ["Practice hola", "Record a greeting"])
        #expect(plan.orderedTasks.first?.id == firstID)

        first.markCompleted()
        #expect(first.status == .completed)
        #expect(first.completedAt != nil)
        #expect(plan.pendingTasks.map(\.title) == ["Record a greeting"])
        #expect(plan.completedTasks.map(\.title) == ["Practice hola"])
        #expect(plan.orderedTasks.map(\.title) == ["Practice hola", "Record a greeting"])

        first.markPending()
        #expect(first.status == .pending)
        #expect(first.completedAt == nil)
        #expect(plan.pendingTasks.map(\.title) == ["Practice hola", "Record a greeting"])
        #expect(plan.completedTasks.isEmpty)
    }

    @Test
    @MainActor
    func movingATaskToFrontPutsItNextAndLeavesOthersAfter() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let first = PlanTask(title: "Practice hola", position: 0)
        let second = PlanTask(title: "Record a greeting", position: 1)
        let third = PlanTask(title: "Review phrases", position: 2)
        let plan = GoalPlan(title: "Spanish greetings", tasks: [first, second, third])
        context.insert(plan)

        plan.moveTaskToFront(third)

        #expect(plan.orderedTasks.map(\.title) == ["Review phrases", "Practice hola", "Record a greeting"])
        #expect(plan.pendingTasks.first?.title == "Review phrases")
    }
}
