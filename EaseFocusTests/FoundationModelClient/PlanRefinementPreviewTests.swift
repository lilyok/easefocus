import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct PlanRefinementPreviewTests {
    private let newID = UUID(uuidString: "00000000-0000-4000-8000-00000000add1")!

    @Test
    @MainActor
    func generatingAPreviewDoesNotMutateSwiftData() async throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let pending = PlanTask(
            title: "Practice hola",
            position: 0,
            searchQuery: "Spanish greetings audio"
        )
        let completed = PlanTask(title: "Record a greeting", position: 1, status: .completed)
        let session = FocusSession(
            plannedDurationSeconds: 1_500,
            elapsedSeconds: 1_200,
            outcome: .completed
        )
        completed.sessions = [session]
        let plan = GoalPlan(title: "Spanish greetings", tasks: [pending, completed])
        context.insert(plan)
        try context.save()

        let before = PlanSnapshot.capturing(plan)
        let client = PreviewPlanRefinementClient(makeID: { newID })
        let preview = try await client.generateRefinementPreview(
            snapshot: before,
            request: "Add speaking exercises",
            locale: Locale(identifier: "en"),
            survey: GoalSurvey(goal: "Learn Spanish greetings"),
            includesResourceSuggestions: false
        )

        #expect(!context.hasChanges)
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.revisions.isEmpty)
        #expect(completed.sessions.count == 1)
        #expect(session.elapsedSeconds == 1_200)
        #expect(preview.after.tasks.contains { $0.id == newID })
        #expect(preview.before == before)
        #expect(preview.after != before)
    }

    @Test
    func previewClientIsDeterministicForTheSameInputs() async throws {
        let snapshot = try pendingSnapshot()
        let first = PreviewPlanRefinementClient(makeID: { newID })
        let second = PreviewPlanRefinementClient(makeID: { newID })

        let firstPreview = try await first.generateRefinementPreview(
            snapshot: snapshot,
            request: "Add speaking exercises",
            locale: Locale(identifier: "en"),
            survey: nil,
            includesResourceSuggestions: false
        )
        let secondPreview = try await second.generateRefinementPreview(
            snapshot: snapshot,
            request: "Add speaking exercises",
            locale: Locale(identifier: "en"),
            survey: nil,
            includesResourceSuggestions: false
        )

        #expect(firstPreview == secondPreview)
        #expect(firstPreview.after.tasks.contains { $0.id == newID })
    }

    @Test
    func regenerationCanAssignANewIDToAnAddedTask() async throws {
        let snapshot = try pendingSnapshot()
        let otherID = UUID(uuidString: "00000000-0000-4000-8000-00000000add2")!
        let first = try await PreviewPlanRefinementClient(makeID: { newID }).generateRefinementPreview(
            snapshot: snapshot,
            request: "Add speaking exercises",
            locale: Locale(identifier: "en"),
            survey: nil,
            includesResourceSuggestions: false
        )
        let second = try await PreviewPlanRefinementClient(makeID: { otherID }).generateRefinementPreview(
            snapshot: snapshot,
            request: "Add speaking exercises",
            locale: Locale(identifier: "en"),
            survey: nil,
            includesResourceSuggestions: false
        )

        #expect(first.after.tasks.last?.id == newID)
        #expect(second.after.tasks.last?.id == otherID)
        #expect(first.before == second.before)
    }

    @Test
    func previewClientStripsResourceQueriesWhenSuggestionsAreDisabled() async throws {
        let snapshot = try pendingSnapshot()
        let preview = try await PreviewPlanRefinementClient(makeID: { newID }).generateRefinementPreview(
            snapshot: snapshot,
            request: "Add speaking exercises",
            locale: Locale(identifier: "en"),
            survey: nil,
            includesResourceSuggestions: false
        )

        #expect(preview.after.tasks.last?.searchQuery == nil)
        #expect(preview.after.tasks.first?.searchQuery == "Spanish greetings audio")
    }

    @Test
    func previewClientKeepsAnOptInQueryOnTheAddedTask() async throws {
        let snapshot = try pendingSnapshot()
        let preview = try await PreviewPlanRefinementClient(makeID: { newID }).generateRefinementPreview(
            snapshot: snapshot,
            request: "Add speaking exercises",
            locale: Locale(identifier: "en"),
            survey: nil,
            includesResourceSuggestions: true
        )

        #expect(preview.after.tasks.last?.searchQuery == "focused speaking practice")
    }

    @Test
    func unavailableClientDoesNotProduceAPreview() async {
        var client = PreviewPlanRefinementClient()
        client.availability = .unavailable(.deviceNotEligible)

        do {
            _ = try await client.generateRefinementPreview(
                snapshot: try pendingSnapshot(),
                request: "Add speaking exercises",
                locale: Locale(identifier: "en"),
                survey: nil,
                includesResourceSuggestions: false
            )
            Issue.record("Expected unavailable generation to fail")
        } catch let error as PlanRefinementGenerationError {
            #expect(error == .unavailable(.unavailable(.deviceNotEligible)))
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test
    func cancelledPreviewDoesNotProduceAPreview() async {
        let client = PreviewPlanRefinementClient()
        let task = Task {
            try await client.generateRefinementPreview(
                snapshot: try pendingSnapshot(),
                request: "Add speaking exercises",
                locale: Locale(identifier: "en"),
                survey: nil,
                includesResourceSuggestions: false
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancelled generation to fail")
        } catch let error as PlanRefinementGenerationError {
            #expect(error == .cancelled)
        } catch is CancellationError {
            // Task cancellation can surface before the client maps the error.
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    private func pendingSnapshot() throws -> PlanSnapshot {
        PlanSnapshot(
            id: UUID(uuidString: "00000000-0000-4000-8000-00000000aaaa")!,
            title: "Spanish greetings",
            details: "A short speaking plan.",
            status: .active,
            tasks: [
                TaskSnapshot(
                    id: UUID(uuidString: "00000000-0000-4000-8000-00000000000a")!,
                    title: "Practice hola",
                    details: nil,
                    position: 0,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: "Spanish greetings audio"
                ),
                TaskSnapshot(
                    id: UUID(uuidString: "00000000-0000-4000-8000-00000000000b")!,
                    title: "Review phrases",
                    details: nil,
                    position: 1,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: nil
                ),
            ]
        )
    }
}
