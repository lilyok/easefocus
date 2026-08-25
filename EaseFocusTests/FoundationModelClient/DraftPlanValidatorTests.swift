import Foundation
import Testing
@testable import EaseFocus

struct DraftPlanValidatorTests {
    @Test
    func acceptsABoundedConcretePlan() {
        let plan = DraftPlanBlueprint(
            title: "Learn Spanish greetings",
            summary: "A short practice plan.",
            tasks: [
                DraftTaskBlueprint(title: "Practice hola and adios", estimatedPomodoros: 1, searchQuery: "Spanish greetings audio"),
                DraftTaskBlueprint(title: "Record a 30-second introduction", estimatedPomodoros: 2, searchQuery: ""),
            ]
        )

        let result = DraftPlanValidator.validate(plan)

        guard case .success(let validated) = result else {
            Issue.record("Expected a valid plan")
            return
        }
        #expect(validated.tasks.count == 2)
    }

    @Test
    func rejectsURLLikeGeneratedText() {
        let plan = DraftPlanBlueprint(
            title: "See https://example.com",
            summary: "Bad",
            tasks: [
                DraftTaskBlueprint(title: "Read a blog", estimatedPomodoros: 1, searchQuery: "")
            ]
        )

        let result = DraftPlanValidator.validate(plan)

        #expect(result == .failure(.urlLikeContent))
    }

    @Test
    func rejectsDuplicateTasks() {
        let plan = DraftPlanBlueprint(
            title: "Practice",
            summary: "Dupes",
            tasks: [
                DraftTaskBlueprint(title: "Repeat the same drill", estimatedPomodoros: 1, searchQuery: ""),
                DraftTaskBlueprint(title: "Repeat the same drill", estimatedPomodoros: 1, searchQuery: ""),
            ]
        )

        #expect(DraftPlanValidator.validate(plan) == .failure(.duplicateTask))
    }
}
