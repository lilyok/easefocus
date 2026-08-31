import Foundation
import Testing
@testable import EaseFocus

struct DraftPlanGenerationEvaluationTests {
    struct Case: Sendable {
        var name: String
        var survey: GoalSurvey
    }

    static let cases: [Case] = {
        var beginner = GoalSurvey()
        beginner.goal = "Learn clearer English pronunciation"
        beginner.experience = .beginner
        beginner.successOutcome = "Read a paragraph out loud without stumbling"
        beginner.sessionsPerWeek = 3

        var deadline = GoalSurvey()
        deadline.goal = "Prepare a five-minute work update"
        deadline.experience = .someExperience
        deadline.successOutcome = "Deliver the update without notes"
        deadline.sessionsPerWeek = 6
        deadline.hasDeadline = true

        var constrained = GoalSurvey()
        constrained.goal = "Build a daily stretching habit"
        constrained.experience = .beginner
        constrained.sessionsPerWeek = 4
        constrained.constraints = "Keep sessions under 20 minutes"

        var sparse = GoalSurvey()
        sparse.goal = "Get better at Spanish"
        sparse.sessionsPerWeek = 1

        return [
            Case(name: "beginner pronunciation", survey: beginner),
            Case(name: "short deadline", survey: deadline),
            Case(name: "time constraint", survey: constrained),
            Case(name: "sparse goal", survey: sparse),
        ]
    }()

    @Test(arguments: cases)
    func promptNeverAsksTheModelToInventURLs(testCase: Case) {
        let message = DraftPlanPrompt.userMessage(for: testCase.survey)
        let instructions = DraftPlanPrompt.instructions(
            locale: Locale(identifier: "en"),
            includesResourceSuggestions: testCase.survey.includesResourceSuggestions
        )

        #expect(message.contains(testCase.survey.trimmedGoal))
        #expect(message.contains("\(testCase.survey.sessionsPerWeek)"))
        #expect(message.contains("Do not include URLs"))
        #expect(instructions.contains("Do not include URLs"))
        #expect(instructions.contains("Every searchQuery must be empty"))
        #expect(message.contains("Every searchQuery must be empty"))
        #expect(!message.lowercased().contains("http://"))
        #expect(!message.lowercased().contains("https://"))
    }

    @Test
    func optInPromptAsksForSelectiveQueries() {
        var survey = GoalSurvey()
        survey.goal = "Learn clearer English pronunciation"
        survey.includesResourceSuggestions = true
        let message = DraftPlanPrompt.userMessage(for: survey)
        let instructions = DraftPlanPrompt.instructions(
            locale: Locale(identifier: "en"),
            includesResourceSuggestions: true
        )

        #expect(message.contains("Resource search suggestions requested: yes"))
        #expect(instructions.contains("not copies of the task title"))
        #expect(message.contains("clear value"))
    }

    @Test(arguments: cases)
    func previewDraftStaysValidAndUsesTheGoal(testCase: Case) async throws {
        let client = PreviewFoundationModelClient()
        let draft = try await client.generateDraftPlan(
            survey: testCase.survey,
            locale: Locale(identifier: "en")
        )

        let validated = DraftPlanValidator.validate(draft)
        guard case .success(let plan) = validated else {
            Issue.record("Preview draft for \(testCase.name) failed validation")
            return
        }
        #expect(plan.title == testCase.survey.trimmedGoal)
        #expect(!plan.tasks.isEmpty)
        #expect(plan.tasks.allSatisfy { DraftPlanValidator.pomodoroRange.contains($0.estimatedPomodoros) })
        #expect(plan.tasks.allSatisfy { $0.searchQuery.isEmpty })
        #expect(plan.tasks.allSatisfy { !$0.searchQuery.lowercased().contains("http") })
    }

    @Test
    func previewDraftIncludesQueriesOnlyWhenTheSurveyOptsIn() async throws {
        var survey = GoalSurvey()
        survey.goal = "Learn clearer English pronunciation"
        survey.includesResourceSuggestions = true
        let client = PreviewFoundationModelClient()
        let draft = try await client.generateDraftPlan(
            survey: survey,
            locale: Locale(identifier: "en")
        )

        #expect(draft.tasks.contains { !$0.searchQuery.isEmpty })
        #expect(draft.tasks.allSatisfy { !$0.searchQuery.lowercased().contains("http") })
        #expect(draft.tasks.allSatisfy { $0.searchQuery.lowercased() != $0.title.lowercased() })
    }

    @Test
    func unavailableClientDoesNotProduceADraft() async {
        var client = PreviewFoundationModelClient()
        client.availability = .unavailable(.deviceNotEligible)

        do {
            _ = try await client.generateDraftPlan(survey: GoalSurvey(), locale: Locale(identifier: "en"))
            Issue.record("Expected unavailable generation to fail")
        } catch let error as FoundationModelClientError {
            #expect(error == .unavailable(.unavailable(.deviceNotEligible)))
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
}
