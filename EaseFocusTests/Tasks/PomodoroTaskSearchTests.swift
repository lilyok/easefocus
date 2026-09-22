import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct PomodoroTaskSearchTests {
    @Test
    @MainActor
    func planLabelColorIsStableForTheSameTitle() {
        let color = PlanLabelColor.color(for: "Fix Bugs in App")
        #expect(color == PlanLabelColor.color(for: "fix bugs in app"))
        #expect(color == PlanLabelColor.color(for: "  Fix Bugs in App  "))
        #expect(PlanLabelColor.color(for: "Fix Bugs in App") != PlanLabelColor.color(for: "Art Blog"))
    }

    @Test
    @MainActor
    func searchMatchesTaskTitleOrPlanTitle() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let plan = GoalPlan(title: "Instagram and TikTok Art Blog Focus Plan")
        let task = PlanTask(title: "Promote Art Blog", position: 0)
        task.plan = plan
        plan.tasks.append(task)
        container.mainContext.insert(plan)

        #expect(PomodoroTaskSearch.matches(task, query: "promote"))
        #expect(PomodoroTaskSearch.matches(task, query: "tiktok"))
        #expect(PomodoroTaskSearch.matches(task, query: "  ART  "))
        #expect(!PomodoroTaskSearch.matches(task, query: "spanish"))
        #expect(PomodoroTaskSearch.matches(task, query: "   "))
    }
}
