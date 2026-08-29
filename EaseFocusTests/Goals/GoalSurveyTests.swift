import Foundation
import Testing
@testable import EaseFocus

struct GoalSurveyTests {
    @Test
    func requiresAGoalBeforeGeneration() {
        var survey = GoalSurvey()
        #expect(!survey.isReadyToGenerate)

        survey.goal = "  Speak Spanish with neighbors  "
        #expect(survey.isReadyToGenerate)
        #expect(survey.trimmedGoal == "Speak Spanish with neighbors")
        #expect(survey.effectiveDeadline == nil)
    }

    @Test
    func roundTripsThroughSnapshotData() throws {
        var survey = GoalSurvey()
        survey.goal = "Clearer pronunciation"
        survey.experience = .someExperience
        survey.sessionsPerWeek = 6
        survey.hasDeadline = true
        survey.deadline = Date(timeIntervalSince1970: 1_800_000_000)
        survey.constraints = "No evenings"

        let decoded = try #require(GoalSurvey.decode(from: survey.encoded()))
        #expect(decoded == survey)
    }
}
