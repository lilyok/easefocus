import Foundation
import Testing
@testable import EaseFocus

struct PlanRefinementPromptTests {
    @Test
    func sendsACompletionSummaryAndStableTaskIDsWithoutSessionDetails() {
        let completedID = UUID(uuidString: "00000000-0000-4000-8000-00000000000c")!
        let pendingID = UUID(uuidString: "00000000-0000-4000-8000-00000000000a")!
        let activeID = UUID(uuidString: "00000000-0000-4000-8000-00000000000d")!
        let snapshot = PlanSnapshot(
            id: UUID(uuidString: "00000000-0000-4000-8000-00000000aaaa")!,
            title: "Spanish greetings",
            details: "A short speaking plan.",
            status: .active,
            tasks: [
                TaskSnapshot(
                    id: pendingID,
                    title: "Practice hola",
                    details: "Say hello clearly",
                    position: 0,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: "Spanish greetings audio"
                ),
                TaskSnapshot(
                    id: completedID,
                    title: "Record a greeting",
                    details: nil,
                    position: 1,
                    estimatedPomodoros: 1,
                    status: .completed,
                    searchQuery: nil
                ),
                TaskSnapshot(
                    id: activeID,
                    title: "Live conversation",
                    details: nil,
                    position: 2,
                    estimatedPomodoros: 2,
                    status: .active,
                    searchQuery: nil
                ),
            ]
        )

        let summary = PlanRefinementPrompt.completionSummary(for: snapshot)
        let listing = PlanRefinementPrompt.planListing(snapshot)
        var survey = GoalSurvey()
        survey.goal = "Learn Spanish greetings"
        survey.constraints = "Evenings only"
        survey.sessionsPerWeek = 5
        let message = PlanRefinementPrompt.userMessage(
            snapshot: snapshot,
            request: "Add speaking exercises",
            locale: Locale(identifier: "es-ES"),
            survey: survey,
            includesResourceSuggestions: false
        )
        let instructions = PlanRefinementPrompt.instructions(
            locale: Locale(identifier: "es-ES"),
            includesResourceSuggestions: false
        )

        #expect(summary.contains("1 of 3 tasks completed"))
        #expect(summary.contains("Record a greeting"))
        #expect(summary.contains("Live conversation"))
        #expect(listing.contains("details=A short speaking plan."))
        #expect(listing.contains("details=Say hello clearly"))
        #expect(listing.contains(pendingID.uuidString))
        #expect(listing.contains(completedID.uuidString))
        #expect(listing.contains(activeID.uuidString))
        #expect(message.contains("Completion summary:"))
        #expect(message.contains(summary))
        #expect(message.contains("Add speaking exercises"))
        #expect(message.contains("Evenings only"))
        #expect(message.contains("5"))
        #expect(message.contains("es-ES"))
        #expect(message.contains("Every searchQuery must be empty"))
        #expect(message.contains("Do not include focus-session details"))
        #expect(instructions.contains("es-ES"))
        #expect(instructions.contains("Never modify, archive, delete, or reorder completed or currently active tasks"))
        #expect(instructions.contains("Never mention or alter focus sessions"))
        #expect(instructions.contains("Never invent a UUID"))
        #expect(instructions.contains("combined number of additions, updates, and archives must be at most 8"))
        #expect(instructions.contains("Leave details empty to keep the current details"))
        #expect(instructions.contains("Do not copy a task title into searchQuery"))
        #expect(!message.lowercased().contains("elapsed"))
        #expect(!message.lowercased().contains("interruption"))
        #expect(!message.lowercased().contains("plannedduration"))
        #expect(!listing.lowercased().contains("session"))
    }

    @Test
    func requestsSelectiveQueriesOnlyWhenResourceSuggestionsAreEnabled() {
        let snapshot = PlanSnapshot(
            id: UUID(),
            title: "Spanish greetings",
            details: nil,
            status: .active,
            tasks: [
                TaskSnapshot(
                    id: UUID(),
                    title: "Practice hola",
                    details: nil,
                    position: 0,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: nil
                )
            ]
        )

        let optedIn = PlanRefinementPrompt.instructions(
            locale: Locale(identifier: "en"),
            includesResourceSuggestions: true
        )
        let optedOut = PlanRefinementPrompt.userMessage(
            snapshot: snapshot,
            request: "Add speaking exercises",
            locale: Locale(identifier: "en"),
            survey: nil,
            includesResourceSuggestions: false
        )

        #expect(optedIn.contains("only for a task where a resource search would provide clear value"))
        #expect(optedOut.contains("Resource search suggestions requested: no"))
        #expect(optedOut.contains("Every searchQuery must be empty"))
    }
}
