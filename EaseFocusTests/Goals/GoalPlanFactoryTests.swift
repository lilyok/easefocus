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

        let plan = try GoalPlanFactory.make(
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
        #expect(plan.orderedTasks.map(\.position) == [0, 1])
        #expect(plan.orderedTasks.first?.searchQuery == "Spanish greetings audio")
        #expect(plan.orderedTasks.last?.searchQuery == nil)
    }

    @Test
    @MainActor
    func rejectsInvalidSearchQueriesBeforePersistence() {
        #expect(throws: GoalPlanFactoryError.invalidSearchQuery(
            index: 0,
            reason: .urlLikeContent
        )) {
            _ = try GoalPlanFactory.make(
                title: "Plan",
                details: nil,
                tasks: [("Task", 1, "https://example.com")],
                source: .generated,
                survey: nil,
                locale: Locale(identifier: "en")
            )
        }
    }

    @Test
    @MainActor
    func createsAManualPlanWithoutFoundationModelsOrSearchQueries() throws {
        let plan = try GoalPlanFactory.make(
            title: "Manual plan",
            details: nil,
            tasks: [("Write an outline", 1, nil)],
            source: .manual,
            survey: nil,
            locale: Locale(identifier: "en")
        )

        #expect(plan.source == .manual)
        #expect(plan.surveySnapshot == nil)
        #expect(plan.orderedTasks.first?.searchQuery == nil)
    }
}
