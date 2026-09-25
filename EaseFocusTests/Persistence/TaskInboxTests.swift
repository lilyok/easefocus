import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct TaskInboxTests {
    @Test
    @MainActor
    func manualAddUsesInboxNotActiveGeneratedPlan() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let locale = Locale(identifier: "en")
        let generated = GoalPlan(
            title: "How to start selling on Etsy",
            status: .active,
            source: .generated
        )
        context.insert(generated)

        let inbox = TaskInbox.plan(from: [generated], in: context, locale: locale)
        #expect(inbox.title == PomodoroCopy.inboxTitle.english)
        #expect(inbox.id != generated.id)

        let task = PlanTask(title: "New task", position: 0)
        inbox.insertTaskAtFront(task)
        #expect(task.plan?.title == PomodoroCopy.inboxTitle.english)
    }

    @Test
    @MainActor
    func retagMovesOnlyThatTaskToANewOrExistingPlan() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let locale = Locale(identifier: "en")
        let shared = GoalPlan(title: "How to start selling on Etsy", source: .generated)
        let first = PlanTask(title: "Research shops", position: 0)
        let second = PlanTask(title: "New task", position: 1)
        shared.tasks = [first, second]
        first.plan = shared
        second.plan = shared
        context.insert(shared)

        TaskInbox.retag(
            second,
            to: "Personal",
            from: [shared],
            in: context,
            locale: locale
        )

        #expect(second.plan?.title == "Personal")
        #expect(first.plan?.title == "How to start selling on Etsy")
        #expect(shared.tasks.map(\.id).contains(second.id) == false)
        #expect(second.plan?.tasks.map(\.id).contains(second.id) == true)
    }

    @Test
    @MainActor
    func emptyTagResolvesToInbox() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let locale = Locale(identifier: "en")
        let plan = GoalPlan(title: "Generated", source: .generated)
        let task = PlanTask(title: "Loose task", position: 0)
        plan.tasks = [task]
        task.plan = plan
        context.insert(plan)

        TaskInbox.retag(task, to: "   ", from: [plan], in: context, locale: locale)

        #expect(task.plan?.title == PomodoroCopy.inboxTitle.english)
    }
}
