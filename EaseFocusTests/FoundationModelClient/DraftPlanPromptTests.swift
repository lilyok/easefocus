import Foundation
import Testing
@testable import EaseFocus

struct DraftPlanPromptTests {
    @Test
    func namesTheOutputLanguageInGenerationInstructions() {
        let instructions = DraftPlanPrompt.instructions(locale: Locale(identifier: "es-ES"))

        #expect(instructions.contains("es-ES"))
        #expect(!instructions.contains("the user's language"))
        #expect(instructions.contains("Do not include URLs"))
        #expect(instructions.contains("generic and task-focused"))
        #expect(instructions.contains("names or other personal survey details"))
        #expect(instructions.contains("deadlines and constraints"))
        #expect(instructions.contains("no URLs or domain names"))
    }

    @Test
    func keepsGeneratedSearchQueriesGenericAndFreeOfSurveyDetails() {
        let instructions = DraftPlanPrompt.instructions(locale: Locale(identifier: "en"))
        var survey = GoalSurvey()
        survey.goal = "Help Alex pass a conversation test by Friday"
        survey.constraints = "Evenings only"
        let message = DraftPlanPrompt.userMessage(for: survey)

        #expect(instructions.contains("Search queries must be generic and task-focused"))
        #expect(instructions.contains("Do not copy names or other personal survey details"))
        #expect(message.contains("Search queries must be generic and task-focused"))
        #expect(message.contains("names or other personal survey details"))
        #expect(message.contains("deadlines and constraints"))
        #expect(!instructions.contains("detect names"))
        #expect(!message.contains("detect names"))
    }

    @Test
    func includesSurveyBoundsInTheUserMessage() {
        var survey = GoalSurvey()
        survey.goal = "Pass a beginner conversation test"
        survey.experience = .beginner
        survey.successOutcome = "Hold a 2-minute chat"
        survey.sessionsPerWeek = 5
        survey.hasDeadline = true
        survey.deadline = Date(timeIntervalSince1970: 1_800_000_000)
        survey.constraints = "No evenings"

        let message = DraftPlanPrompt.userMessage(for: survey)

        #expect(message.contains("Pass a beginner conversation test"))
        #expect(message.contains("beginner"))
        #expect(message.contains("Hold a 2-minute chat"))
        #expect(message.contains("5"))
        #expect(message.contains("No evenings"))
        #expect(message.contains("Do not include URLs"))
        #expect(message.contains("generic and task-focused"))
        #expect(message.contains("personal survey details"))
        #expect(!message.contains("http"))
    }
}
