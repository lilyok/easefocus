import Foundation
import Testing
@testable import EaseFocus

struct ResourceSearchSuggestionPolicyTests {
    @Test
    func stripsEveryQueryWhenSuggestionsAreDisabled() {
        let plan = DraftPlanBlueprint(
            title: "Spanish greetings",
            summary: "Practice speaking.",
            tasks: [
                DraftTaskBlueprint(
                    title: "Practice hola",
                    estimatedPomodoros: 1,
                    searchQuery: "Spanish greetings audio"
                ),
                DraftTaskBlueprint(
                    title: "Record a greeting",
                    estimatedPomodoros: 1,
                    searchQuery: "https://example.com"
                ),
            ]
        )

        let applied = ResourceSearchSuggestionPolicy.applied(
            to: plan,
            includesResourceSuggestions: false
        )

        #expect(applied.tasks.allSatisfy { $0.searchQuery.isEmpty })
    }

    @Test
    func keepsTaskSpecificQueriesAndDropsTitleCopiesWhenEnabled() {
        let plan = DraftPlanBlueprint(
            title: "Spanish greetings",
            summary: "Practice speaking.",
            tasks: [
                DraftTaskBlueprint(
                    title: "Practice hola",
                    estimatedPomodoros: 1,
                    searchQuery: "Spanish greetings audio"
                ),
                DraftTaskBlueprint(
                    title: "Practice hola",
                    estimatedPomodoros: 1,
                    searchQuery: "Practice hola"
                ),
                DraftTaskBlueprint(
                    title: "Record a greeting",
                    estimatedPomodoros: 1,
                    searchQuery: "   "
                ),
            ]
        )

        let applied = ResourceSearchSuggestionPolicy.applied(
            to: plan,
            includesResourceSuggestions: true
        )

        #expect(applied.tasks[0].searchQuery == "Spanish greetings audio")
        #expect(applied.tasks[1].searchQuery.isEmpty)
        #expect(applied.tasks[2].searchQuery.isEmpty)
    }

    @Test
    func hidesDraftResourceControlsUnlessTheUserOptedIn() {
        #expect(
            ResourceSearchControlPolicy.draftCreation(
                source: .manual,
                includesResourceSuggestions: true,
                hasQuery: true,
                isAdding: true
            ) == .hidden
        )
        #expect(
            ResourceSearchControlPolicy.draftCreation(
                source: .generated,
                includesResourceSuggestions: false,
                hasQuery: true,
                isAdding: true
            ) == .hidden
        )
        #expect(
            ResourceSearchControlPolicy.draftCreation(
                source: .generated,
                includesResourceSuggestions: true,
                hasQuery: false,
                isAdding: false
            ) == .addAction
        )
        #expect(
            ResourceSearchControlPolicy.draftCreation(
                source: .generated,
                includesResourceSuggestions: true,
                hasQuery: true,
                isAdding: false
            ) == .editor
        )
    }

    @Test
    func expandsSavedPlanEditorOnlyWhenAQueryExistsOrTheUserAddsOne() {
        #expect(ResourceSearchControlPolicy.savedPlan(hasQuery: false, isAdding: false) == .addAction)
        #expect(ResourceSearchControlPolicy.savedPlan(hasQuery: true, isAdding: false) == .editor)
        #expect(ResourceSearchControlPolicy.savedPlan(hasQuery: false, isAdding: true) == .editor)
    }
}
