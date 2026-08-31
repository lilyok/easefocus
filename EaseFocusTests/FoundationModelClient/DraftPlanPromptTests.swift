import Foundation
import Testing
@testable import EaseFocus

struct DraftPlanPromptTests {
    @Test
    func namesTheOutputLanguageInGenerationInstructions() {
        let instructions = DraftPlanPrompt.instructions(
            locale: Locale(identifier: "es-ES"),
            includesResourceSuggestions: false
        )

        #expect(instructions.contains("es-ES"))
        #expect(!instructions.contains("the user's language"))
        #expect(instructions.contains("Do not include URLs"))
        #expect(instructions.contains("Every searchQuery must be empty"))
    }

    @Test
    func omitsResourceSuggestionsWhenTheSurveyDefaultIsOff() {
        let instructions = DraftPlanPrompt.instructions(
            locale: Locale(identifier: "en"),
            includesResourceSuggestions: false
        )
        var survey = GoalSurvey()
        survey.goal = "Help Alex pass a conversation test by Friday"
        survey.constraints = "Evenings only"
        let message = DraftPlanPrompt.userMessage(for: survey)

        #expect(!survey.includesResourceSuggestions)
        #expect(instructions.contains("Do not generate resource search suggestions"))
        #expect(instructions.contains("Every searchQuery must be empty"))
        #expect(message.contains("Resource search suggestions requested: no"))
        #expect(message.contains("Every searchQuery must be empty"))
        #expect(!instructions.contains("detect names"))
        #expect(!message.contains("detect names"))
    }

    @Test
    func requestsSelectiveTaskSpecificQueriesWhenOptedIn() {
        let instructions = DraftPlanPrompt.instructions(
            locale: Locale(identifier: "en"),
            includesResourceSuggestions: true
        )
        var survey = GoalSurvey()
        survey.goal = "Help Alex pass a conversation test by Friday"
        survey.includesResourceSuggestions = true
        let message = DraftPlanPrompt.userMessage(for: survey)

        #expect(instructions.contains("only for a task where a resource search would provide clear value"))
        #expect(instructions.contains("not copies of the task title"))
        #expect(instructions.contains("names or other personal survey details"))
        #expect(instructions.contains("deadlines and constraints"))
        #expect(instructions.contains("no URLs or domain names"))
        #expect(message.contains("Resource search suggestions requested: yes"))
        #expect(message.contains("not copies of the task title"))
        #expect(message.contains("names or other personal survey details"))
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
        #expect(message.contains("Every searchQuery must be empty"))
        #expect(!message.contains("http"))
    }
}
