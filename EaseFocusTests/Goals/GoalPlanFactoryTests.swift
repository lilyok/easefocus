import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct GoalPlanFactoryTests {
    @Test
    @MainActor
    func persistsAGeneratedPlanWithSurveyAndSearchQueries() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        var survey = GoalSurvey()
        survey.goal = "Learn Spanish greetings"
        survey.sessionsPerWeek = 3

        let plan = GoalPlanFactory.make(
            title: "Spanish greetings",
            details: "A short speaking plan.",
            tasks: [
                ("Practice hola", 1, "Spanish greetings audio"),
                ("Record a greeting", 2, ""),
            ],
            source: .generated,
            survey: survey,
            locale: Locale(identifier: "es-ES")
        )
        container.mainContext.insert(plan)
        try container.mainContext.save()

        #expect(plan.source == .generated)
        #expect(plan.preferredLocaleIdentifier == "es-ES")
        #expect(GoalSurvey.decode(from: plan.surveySnapshot)?.goal == "Learn Spanish greetings")
        #expect(plan.orderedTasks.map(\.title) == ["Practice hola", "Record a greeting"])
        #expect(plan.orderedTasks.first?.searchQuery == "Spanish greetings audio")
        #expect(plan.orderedTasks.last?.searchQuery == nil)
    }
}
