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
        #expect(!message.contains("http"))
    }
}
