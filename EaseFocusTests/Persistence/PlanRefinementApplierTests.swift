import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct PlanRefinementApplierTests {
    private enum SampleError: Error {
        case diskFull
    }

    private let newID = UUID(uuidString: "00000000-0000-4000-8000-00000000add1")!

    @Test
    @MainActor
    func appliesAValidatedPreviewAndRecordsARevision() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let pending = PlanTask(
            title: "Practice hola",
            position: 0,
            searchQuery: "Spanish greetings audio"
        )
        let completed = PlanTask(title: "Record a greeting", position: 1, status: .completed)
        let sessionID = UUID()
        let session = FocusSession(
            id: sessionID,
            plannedDurationSeconds: 1_500,
            elapsedSeconds: 1_200,
            outcome: .completed
        )
        completed.sessions = [session]
        let plan = GoalPlan(title: "Spanish greetings", details: "A short speaking plan.", tasks: [pending, completed])
        context.insert(plan)
        try context.save()

        let preview = try PlanRefinementPreviewFactory.make(
            snapshot: PlanSnapshot.capturing(plan),
            request: "Add speaking exercises",
            proposal: PlanRefinementProposal(
                changeSummary: "Add a speaking drill.",
                additions: [
                    PlanRefinementAddition(
                        localID: "new-1",
                        title: "Shadow a dialogue",
                        details: "",
                        estimatedPomodoros: 1,
                        searchQuery: ""
                    )
                ],
                updates: [],
                archivedTaskIDs: [],
                pendingTaskOrder: [pending.id.uuidString, "new-1"]
            ),
            includesResourceSuggestions: false,
            makeID: { newID }
        )

        try PlanRefinementApplier.apply(preview, to: plan, in: context, now: Date(timeIntervalSince1970: 42))

        #expect(try PlanSnapshot.capturing(plan).validated() == preview.after)
        #expect(plan.orderedTasks.map(\.title) == ["Practice hola", "Record a greeting", "Shadow a dialogue"])
        #expect(plan.orderedTasks.last?.id == newID)
        #expect(plan.orderedRevisions.count == 1)
        #expect(plan.orderedRevisions.first?.source == .model)
        #expect(plan.orderedRevisions.first?.reason == "Add speaking exercises")
        #expect(plan.orderedRevisions.first?.changeSummary == "Add a speaking drill.")
        #expect(try plan.orderedRevisions.first?.decodedBeforeSnapshot() == preview.before)
        #expect(try plan.orderedRevisions.first?.decodedAfterSnapshot() == preview.after)
        #expect(completed.sessions.map(\.id) == [sessionID])
        #expect(completed.sessions.first?.elapsedSeconds == 1_200)
        #expect(completed.sessions.first?.plannedDurationSeconds == 1_500)
        #expect(plan.updatedAt == Date(timeIntervalSince1970: 42))
    }

    @Test
    @MainActor
    func rejectsAStalePreviewWithoutMutatingThePlan() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let pending = PlanTask(title: "Practice hola", position: 0)
        let plan = GoalPlan(title: "Spanish greetings", tasks: [pending])
        context.insert(plan)
        try context.save()

        let preview = try PlanRefinementPreviewFactory.make(
            snapshot: PlanSnapshot.capturing(plan),
            request: "Rename the drill",
            proposal: PlanRefinementProposal(
                changeSummary: "Rename a pending task.",
                additions: [],
                updates: [
                    PlanRefinementUpdate(
                        taskID: pending.id.uuidString,
                        title: "Practice hola and adios",
                        details: "",
                        estimatedPomodoros: 1,
                        searchQuery: ""
                    )
                ],
                archivedTaskIDs: [],
                pendingTaskOrder: [pending.id.uuidString]
            ),
            includesResourceSuggestions: false
        )

        pending.title = "Changed after preview"
        try context.save()

        #expect(throws: PlanRefinementApplierError.stalePreview) {
            try PlanRefinementApplier.apply(preview, to: plan, in: context)
        }
        #expect(plan.orderedTasks.map(\.title) == ["Changed after preview"])
        #expect(plan.revisions.isEmpty)
    }

    @Test
    @MainActor
    func saveFailureRollsBackEveryRefinementMutation() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let pending = PlanTask(title: "Practice hola", position: 0)
        let completed = PlanTask(title: "Record a greeting", position: 1, status: .completed)
        let session = FocusSession(plannedDurationSeconds: 1_500, elapsedSeconds: 900, outcome: .completed)
        completed.sessions = [session]
        let plan = GoalPlan(title: "Spanish greetings", tasks: [pending, completed])
        context.insert(plan)
        try context.save()
        let originalUpdatedAt = plan.updatedAt

        let preview = try PlanRefinementPreviewFactory.make(
            snapshot: PlanSnapshot.capturing(plan),
            request: "Add speaking exercises",
            proposal: PlanRefinementProposal(
                changeSummary: "Add a speaking drill.",
                additions: [
                    PlanRefinementAddition(
                        localID: "new-1",
                        title: "Shadow a dialogue",
                        details: "",
                        estimatedPomodoros: 1,
                        searchQuery: ""
                    )
                ],
                updates: [
                    PlanRefinementUpdate(
                        taskID: pending.id.uuidString,
                        title: "Practice hola and adios",
                        details: "",
                        estimatedPomodoros: 1,
                        searchQuery: ""
                    )
                ],
                archivedTaskIDs: [],
                pendingTaskOrder: [pending.id.uuidString, "new-1"]
            ),
            includesResourceSuggestions: false,
            makeID: { newID }
        )

        #expect(throws: PlanRefinementApplierError.saveFailed) {
            try PlanRefinementApplier.apply(preview, to: plan, in: context) { _ in
                throw SampleError.diskFull
            }
        }

        #expect(plan.orderedTasks.map(\.title) == ["Practice hola", "Record a greeting"])
        #expect(plan.orderedTasks.map(\.id) == [pending.id, completed.id])
        #expect(plan.revisions.isEmpty)
        #expect(plan.updatedAt == originalUpdatedAt)
        #expect(completed.sessions.count == 1)
        #expect(completed.sessions.first?.elapsedSeconds == 900)
        #expect(try context.fetch(FetchDescriptor<PlanTask>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<PlanRevision>()).isEmpty)
    }

    @Test
    @MainActor
    func preservesFocusSessionsWhenArchivingAndReorderingPendingWork() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let first = PlanTask(title: "Practice hola", position: 0)
        let completed = PlanTask(title: "Record a greeting", position: 1, status: .completed)
        let second = PlanTask(title: "Review phrases", position: 2)
        let session = FocusSession(
            plannedDurationSeconds: 1_500,
            elapsedSeconds: 1_200,
            outcome: .completed
        )
        completed.sessions = [session]
        let pendingSession = FocusSession(
            plannedDurationSeconds: 1_500,
            elapsedSeconds: 300,
            outcome: .interrupted
        )
        first.sessions = [pendingSession]
        let plan = GoalPlan(title: "Spanish greetings", tasks: [first, completed, second])
        context.insert(plan)
        try context.save()

        let preview = try PlanRefinementPreviewFactory.make(
            snapshot: PlanSnapshot.capturing(plan),
            request: "Archive review and keep speaking first",
            proposal: PlanRefinementProposal(
                changeSummary: "Archive review and reorder pending work.",
                additions: [],
                updates: [],
                archivedTaskIDs: [second.id.uuidString],
                pendingTaskOrder: [first.id.uuidString]
            ),
            includesResourceSuggestions: false
        )

        try PlanRefinementApplier.apply(preview, to: plan, in: context)

        #expect(plan.orderedTasks.map(\.status) == [.pending, .completed, .archived])
        #expect(completed.sessions.first?.elapsedSeconds == 1_200)
        #expect(first.sessions.first?.elapsedSeconds == 300)
        #expect(first.sessions.first?.outcome == .interrupted)
        #expect(second.sessions.isEmpty)
        #expect(try PlanSnapshot.capturing(plan).validated() == preview.after)
    }

    @Test
    @MainActor
    func rejectsAPendingTaskPromotedToCompletedOrActive() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let pending = PlanTask(title: "Practice hola", details: "Say hello clearly", position: 0)
        let plan = GoalPlan(title: "Spanish greetings", tasks: [pending])
        context.insert(plan)
        try context.save()

        let preview = try PlanRefinementPreviewFactory.make(
            snapshot: PlanSnapshot.capturing(plan),
            request: "Rename the drill",
            proposal: PlanRefinementProposal(
                changeSummary: "Rename a pending task.",
                additions: [],
                updates: [
                    PlanRefinementUpdate(
                        taskID: pending.id.uuidString,
                        title: "Practice hola and adios",
                        details: "Say hello clearly",
                        estimatedPomodoros: 1,
                        searchQuery: ""
                    )
                ],
                archivedTaskIDs: [],
                pendingTaskOrder: [pending.id.uuidString]
            ),
            includesResourceSuggestions: false
        )

        var completed = preview
        completed.after.tasks[0].status = .completed
        #expect(throws: PlanRefinementApplierError.malformedPreview) {
            try PlanRefinementApplier.apply(completed, to: plan, in: context)
        }

        var active = preview
        active.after.tasks[0].status = .active
        #expect(throws: PlanRefinementApplierError.malformedPreview) {
            try PlanRefinementApplier.apply(active, to: plan, in: context)
        }

        #expect(plan.orderedTasks.map(\.status) == [.pending])
        #expect(plan.orderedTasks.first?.title == "Practice hola")
        #expect(plan.revisions.isEmpty)
    }

    @Test
    @MainActor
    func rejectsANewTaskThatIsNotPending() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let pending = PlanTask(title: "Practice hola", position: 0)
        let plan = GoalPlan(title: "Spanish greetings", tasks: [pending])
        context.insert(plan)
        try context.save()

        let preview = try PlanRefinementPreviewFactory.make(
            snapshot: PlanSnapshot.capturing(plan),
            request: "Add speaking exercises",
            proposal: PlanRefinementProposal(
                changeSummary: "Add a speaking drill.",
                additions: [
                    PlanRefinementAddition(
                        localID: "new-1",
                        title: "Shadow a dialogue",
                        details: "",
                        estimatedPomodoros: 1,
                        searchQuery: ""
                    )
                ],
                updates: [],
                archivedTaskIDs: [],
                pendingTaskOrder: [pending.id.uuidString, "new-1"]
            ),
            includesResourceSuggestions: false,
            makeID: { newID }
        )

        var tampered = preview
        tampered.after.tasks[tampered.after.tasks.count - 1].status = .completed
        #expect(throws: PlanRefinementApplierError.malformedPreview) {
            try PlanRefinementApplier.apply(tampered, to: plan, in: context)
        }
        #expect(plan.orderedTasks.map(\.title) == ["Practice hola"])
        #expect(plan.revisions.isEmpty)
    }

    @Test
    @MainActor
    func rejectsATamperedAfterSnapshotWithMalformedPendingContent() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let pending = PlanTask(title: "Practice hola", details: "Say hello clearly", position: 0)
        let plan = GoalPlan(title: "Spanish greetings", tasks: [pending])
        context.insert(plan)
        try context.save()

        let preview = try PlanRefinementPreviewFactory.make(
            snapshot: PlanSnapshot.capturing(plan),
            request: "Rename the drill",
            proposal: PlanRefinementProposal(
                changeSummary: "Rename a pending task.",
                additions: [],
                updates: [
                    PlanRefinementUpdate(
                        taskID: pending.id.uuidString,
                        title: "Practice hola and adios",
                        details: "Say hello clearly",
                        estimatedPomodoros: 1,
                        searchQuery: ""
                    )
                ],
                archivedTaskIDs: [],
                pendingTaskOrder: [pending.id.uuidString]
            ),
            includesResourceSuggestions: false
        )

        var emptyTitle = preview
        emptyTitle.after.tasks[0].title = ""
        #expect(throws: PlanRefinementApplierError.malformedPreview) {
            try PlanRefinementApplier.apply(emptyTitle, to: plan, in: context)
        }

        var urlTitle = preview
        urlTitle.after.tasks[0].title = "See https://example.com"
        #expect(throws: PlanRefinementApplierError.malformedPreview) {
            try PlanRefinementApplier.apply(urlTitle, to: plan, in: context)
        }

        var badEstimate = preview
        badEstimate.after.tasks[0].estimatedPomodoros = 0
        #expect(throws: PlanRefinementApplierError.malformedPreview) {
            try PlanRefinementApplier.apply(badEstimate, to: plan, in: context)
        }

        var badQuery = preview
        badQuery.after.tasks[0].searchQuery = "https://example.com"
        #expect(throws: PlanRefinementApplierError.malformedPreview) {
            try PlanRefinementApplier.apply(badQuery, to: plan, in: context)
        }

        var emptySummary = preview
        emptySummary.changeSummary = "   "
        #expect(throws: PlanRefinementApplierError.malformedPreview) {
            try PlanRefinementApplier.apply(emptySummary, to: plan, in: context)
        }

        #expect(plan.orderedTasks.first?.title == "Practice hola")
        #expect(plan.orderedTasks.first?.details == "Say hello clearly")
        #expect(plan.revisions.isEmpty)
    }
}
