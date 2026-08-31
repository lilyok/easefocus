import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct PlanTaskSearchQueryTests {
    @Test
    @MainActor
    func editsAndDeletesAPersistedSearchQuery() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let task = PlanTask(title: "Practice hola", position: 0, searchQuery: "Spanish greetings audio")
        let plan = GoalPlan(title: "Spanish greetings", tasks: [task])
        context.insert(plan)
        try context.save()

        #expect(task.applySearchQuery("  beginner Spanish pronunciation  ") == .success("beginner Spanish pronunciation"))
        try context.save()
        #expect(task.searchQuery == "beginner Spanish pronunciation")

        #expect(task.applySearchQuery("   ") == .success(nil))
        try context.save()
        #expect(task.searchQuery == nil)
    }

    @Test
    @MainActor
    func preservesAnExistingQueryWithoutBulkDeleting() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let withQuery = PlanTask(title: "Practice hola", position: 0, searchQuery: "Spanish greetings audio")
        let withoutQuery = PlanTask(title: "Record a greeting", position: 1)
        let plan = GoalPlan(title: "Spanish greetings", tasks: [withQuery, withoutQuery])
        context.insert(plan)
        try context.save()

        #expect(withQuery.searchQuery == "Spanish greetings audio")
        #expect(withoutQuery.searchQuery == nil)
        #expect(ResourceSearchControlPolicy.savedPlan(hasQuery: true, isAdding: false) == .editor)
        #expect(ResourceSearchControlPolicy.savedPlan(hasQuery: false, isAdding: false) == .addAction)
    }

    @Test
    @MainActor
    func rejectsInvalidQueriesWithoutChangingThePersistedValue() throws {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let task = PlanTask(title: "Practice hola", position: 0, searchQuery: "Spanish greetings audio")
        context.insert(GoalPlan(title: "Spanish greetings", tasks: [task]))
        try context.save()

        #expect(task.applySearchQuery("https://example.com/lesson") == .failure(.urlLikeContent))
        #expect(
            task.applySearchQuery(String(repeating: "a", count: SearchQueryValidator.maximumLength + 1))
                == .failure(.tooLong)
        )
        try context.save()
        #expect(task.searchQuery == "Spanish greetings audio")
    }

    @Test
    @MainActor
    func keepsUnrelatedPendingEditsWhenALaterSaveFails() {
        let task = PlanTask(title: "Practice hola", position: 0, searchQuery: "Spanish greetings audio")
        task.title = "Practice hola and adios"
        #expect(task.applySearchQuery("beginner Spanish pronunciation") == .success("beginner Spanish pronunciation"))

        let result = PersistenceSaving.result {
            throw SampleSaveError.diskFull
        }

        #expect(result != .saved)
        #expect(task.title == "Practice hola and adios")
        #expect(task.searchQuery == "beginner Spanish pronunciation")

        let retried = PersistenceSaving.result {}
        #expect(retried == .saved)
        #expect(task.title == "Practice hola and adios")
        #expect(task.searchQuery == "beginner Spanish pronunciation")
    }
}

private enum SampleSaveError: Error, LocalizedError {
    case diskFull

    var errorDescription: String? {
        "The disk is full."
    }
}
