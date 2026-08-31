import Foundation
import Testing
@testable import EaseFocus

struct PlanRefinementValidatorTests {
    private let planID = UUID(uuidString: "00000000-0000-4000-8000-00000000aaaa")!
    private let pendingA = UUID(uuidString: "00000000-0000-4000-8000-00000000000a")!
    private let pendingB = UUID(uuidString: "00000000-0000-4000-8000-00000000000b")!
    private let pendingE = UUID(uuidString: "00000000-0000-4000-8000-00000000000e")!
    private let completedC = UUID(uuidString: "00000000-0000-4000-8000-00000000000c")!
    private let activeD = UUID(uuidString: "00000000-0000-4000-8000-00000000000d")!
    private let newID = UUID(uuidString: "00000000-0000-4000-8000-00000000add1")!

    @Test
    func addsAPendingTask() throws {
        let before = pendingSnapshot()
        let preview = try makePreview(
            snapshot: before,
            proposal: proposal(
                additions: [addition(title: "Shadow a dialogue")],
                order: [pendingA.uuidString, pendingB.uuidString, "new-1"]
            )
        )

        #expect(preview.after.tasks.map(\.title) == [
            "Practice hola",
            "Review phrases",
            "Shadow a dialogue",
        ])
        #expect(preview.after.tasks.last?.id == newID)
        #expect(preview.after.tasks.last?.status == .pending)
        #expect(preview.after.tasks.last?.estimatedPomodoros == 1)
        #expect(preview.before == before)
    }

    @Test
    func modifiesAPendingTaskAndLeavesTheOtherUnchanged() throws {
        let before = pendingSnapshot()
        let preview = try makePreview(
            snapshot: before,
            proposal: proposal(
                updates: [
                    PlanRefinementUpdate(
                        taskID: pendingA.uuidString,
                        title: "Practice hola and adios",
                        details: "Speak slowly",
                        estimatedPomodoros: 2,
                        searchQuery: ""
                    )
                ],
                order: [pendingA.uuidString, pendingB.uuidString]
            )
        )

        #expect(preview.after.tasks[0].title == "Practice hola and adios")
        #expect(preview.after.tasks[0].details == "Speak slowly")
        #expect(preview.after.tasks[0].estimatedPomodoros == 2)
        #expect(preview.after.tasks[0].id == pendingA)
        #expect(preview.after.tasks[1] == before.tasks[1])
    }

    @Test
    func reordersPendingTasks() throws {
        let before = pendingSnapshot()
        let preview = try makePreview(
            snapshot: before,
            proposal: proposal(order: [pendingB.uuidString, pendingA.uuidString])
        )

        #expect(preview.after.tasks.map(\.id) == [pendingB, pendingA])
        #expect(preview.after.tasks.map(\.position) == [0, 1])
        #expect(preview.after.tasks.map(\.title) == ["Review phrases", "Practice hola"])
    }

    @Test
    func archivesAPendingTask() throws {
        let before = pendingSnapshot()
        let preview = try makePreview(
            snapshot: before,
            proposal: proposal(
                archived: [pendingB.uuidString],
                order: [pendingA.uuidString]
            )
        )

        #expect(preview.after.tasks.map(\.id) == [pendingA, pendingB])
        #expect(preview.after.tasks[1].status == .archived)
        #expect(preview.after.tasks[1].title == "Review phrases")
        #expect(preview.after.tasks[0].status == .pending)
    }

    @Test
    func appliesCombinedChangesAndFinalOrderingAroundProtectedTasks() throws {
        let before = mixedSnapshot()
        let preview = try makePreview(
            snapshot: before,
            proposal: proposal(
                summary: "Add a drill, rename practice, and archive the reading.",
                additions: [addition(title: "Shadow a dialogue")],
                updates: [
                    PlanRefinementUpdate(
                        taskID: pendingA.uuidString,
                        title: "Practice hola and adios",
                        details: "",
                        estimatedPomodoros: 2,
                        searchQuery: ""
                    )
                ],
                archived: [pendingE.uuidString],
                order: [pendingB.uuidString, "new-1", pendingA.uuidString]
            )
        )

        #expect(preview.after.tasks.map(\.title) == [
            "Review phrases",
            "Record a greeting",
            "Shadow a dialogue",
            "Live conversation",
            "Read a dialogue",
            "Practice hola and adios",
        ])
        #expect(preview.after.tasks.map(\.status) == [
            .pending, .completed, .pending, .active, .archived, .pending,
        ])
        #expect(preview.after.tasks[1].id == completedC)
        #expect(preview.after.tasks[3].id == activeD)
        #expect(preview.after.tasks[2].id == newID)
        #expect(preview.changeSummary.contains("archive"))
    }

    @Test
    func rejectsUnknownMalformedAndDuplicatedIDs() {
        let before = pendingSnapshot()

        #expect(throws: PlanRefinementValidationError.unknownTaskID) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    updates: [
                        PlanRefinementUpdate(
                            taskID: UUID().uuidString,
                            title: "Nope",
                            details: "",
                            estimatedPomodoros: 1,
                            searchQuery: ""
                        )
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString]
                )
            )
        }

        #expect(throws: PlanRefinementValidationError.malformedTaskID) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    updates: [
                        PlanRefinementUpdate(
                            taskID: "not-a-uuid",
                            title: "Nope",
                            details: "",
                            estimatedPomodoros: 1,
                            searchQuery: ""
                        )
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString]
                )
            )
        }

        #expect(throws: PlanRefinementValidationError.malformedTaskID) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    additions: [
                        addition(localID: newID.uuidString, title: "Uses a UUID")
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString, newID.uuidString]
                )
            )
        }

        #expect(throws: PlanRefinementValidationError.duplicateOperation) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    updates: [
                        PlanRefinementUpdate(
                            taskID: pendingA.uuidString,
                            title: "Once",
                            details: "",
                            estimatedPomodoros: 1,
                            searchQuery: ""
                        ),
                        PlanRefinementUpdate(
                            taskID: pendingA.uuidString,
                            title: "Twice",
                            details: "",
                            estimatedPomodoros: 1,
                            searchQuery: ""
                        ),
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString]
                )
            )
        }

        #expect(throws: PlanRefinementValidationError.conflictingOperations) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    updates: [
                        PlanRefinementUpdate(
                            taskID: pendingB.uuidString,
                            title: "Review phrases",
                            details: "",
                            estimatedPomodoros: 1,
                            searchQuery: ""
                        )
                    ],
                    archived: [pendingB.uuidString],
                    order: [pendingA.uuidString]
                )
            )
        }

        #expect(throws: PlanRefinementValidationError.duplicateInOrdering) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(order: [pendingA.uuidString, pendingA.uuidString])
            )
        }

        #expect(throws: PlanRefinementValidationError.missingFromOrdering) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(order: [pendingA.uuidString])
            )
        }
    }

    @Test
    func rejectsAttemptsToChangeCompletedOrActiveTasks() {
        let before = mixedSnapshot()
        let pendingOrder = [pendingA.uuidString, pendingB.uuidString, pendingE.uuidString]

        #expect(throws: PlanRefinementValidationError.protectedTaskReferenced) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    updates: [
                        PlanRefinementUpdate(
                            taskID: completedC.uuidString,
                            title: "Rewrite completed work",
                            details: "",
                            estimatedPomodoros: 1,
                            searchQuery: ""
                        )
                    ],
                    order: pendingOrder
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.protectedTaskReferenced) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    archived: [activeD.uuidString],
                    order: pendingOrder
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.protectedTaskReferenced) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    order: [activeD.uuidString, pendingA.uuidString, pendingB.uuidString, pendingE.uuidString]
                )
            )
        }
    }

    @Test
    func rejectsInvalidEstimatesTextAndSearchQueries() {
        let before = pendingSnapshot()

        #expect(throws: PlanRefinementValidationError.invalidPomodoroEstimate) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    updates: [
                        PlanRefinementUpdate(
                            taskID: pendingA.uuidString,
                            title: "Practice hola",
                            details: "",
                            estimatedPomodoros: 0,
                            searchQuery: ""
                        )
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString]
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.invalidPomodoroEstimate) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    additions: [addition(title: "Extra", estimatedPomodoros: 9)],
                    order: [pendingA.uuidString, pendingB.uuidString, "new-1"]
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.emptyTaskTitle) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    additions: [addition(title: "   ")],
                    order: [pendingA.uuidString, pendingB.uuidString, "new-1"]
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.textTooLong) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    additions: [
                        addition(title: String(repeating: "a", count: PlanRefinementLimits.maximumTitleLength + 1))
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString, "new-1"]
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.urlLikeContent) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    additions: [addition(title: "See https://example.com")],
                    order: [pendingA.uuidString, pendingB.uuidString, "new-1"]
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.invalidSearchQuery(.urlLikeContent)) {
            _ = try makePreview(
                snapshot: before,
                includesResourceSuggestions: true,
                proposal: proposal(
                    additions: [
                        addition(title: "Find a lesson", searchQuery: "https://example.com/lesson")
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString, "new-1"]
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.invalidSearchQuery(.tooLong)) {
            _ = try makePreview(
                snapshot: before,
                includesResourceSuggestions: true,
                proposal: proposal(
                    additions: [
                        addition(
                            title: "Find a lesson",
                            searchQuery: String(repeating: "a", count: SearchQueryValidator.maximumLength + 1)
                        )
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString, "new-1"]
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.emptyChangeSummary) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    summary: "   ",
                    order: [pendingB.uuidString, pendingA.uuidString]
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.emptyRequest) {
            _ = try PlanRefinementPreviewFactory.make(
                snapshot: before,
                request: "   ",
                proposal: proposal(order: [pendingB.uuidString, pendingA.uuidString]),
                includesResourceSuggestions: false,
                makeID: { newID }
            )
        }
    }

    @Test
    func rejectsResourceQueriesWhenSuggestionsAreDisabledAndPreservesExistingQueries() throws {
        let before = pendingSnapshot()

        #expect(throws: PlanRefinementValidationError.resourceQueryWhenDisabled) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    additions: [
                        addition(title: "Shadow a dialogue", searchQuery: "focused speaking practice")
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString, "new-1"]
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.resourceQueryWhenDisabled) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(
                    updates: [
                        PlanRefinementUpdate(
                            taskID: pendingA.uuidString,
                            title: "Practice hola",
                            details: "",
                            estimatedPomodoros: 1,
                            searchQuery: "Spanish greetings audio"
                        )
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString]
                )
            )
        }

        let preserved = try makePreview(
            snapshot: before,
            proposal: proposal(
                updates: [
                    PlanRefinementUpdate(
                        taskID: pendingA.uuidString,
                        title: "Practice hola and adios",
                        details: "",
                        estimatedPomodoros: 1,
                        searchQuery: ""
                    )
                ],
                order: [pendingA.uuidString, pendingB.uuidString]
            )
        )
        #expect(preserved.after.tasks[0].searchQuery == "Spanish greetings audio")
        #expect(preserved.after.tasks[0].title == "Practice hola and adios")
        #expect(preserved.after.tasks[0].details == "Say hello clearly")
    }

    @Test
    func preservesExistingDetailsWhenAnUnrelatedRefinementOnlyChangesTitle() throws {
        let before = pendingSnapshot()
        let preview = try makePreview(
            snapshot: before,
            proposal: proposal(
                updates: [
                    PlanRefinementUpdate(
                        taskID: pendingA.uuidString,
                        title: "Practice hola and adios",
                        details: "",
                        estimatedPomodoros: 1,
                        searchQuery: ""
                    )
                ],
                order: [pendingA.uuidString, pendingB.uuidString]
            )
        )

        #expect(preview.after.tasks[0].title == "Practice hola and adios")
        #expect(preview.after.tasks[0].details == "Say hello clearly")
        #expect(preview.after.tasks[1].details == nil)
    }

    @Test
    func preservesExistingDetailsWhenAddingATask() throws {
        let before = pendingSnapshot()
        let preview = try makePreview(
            snapshot: before,
            proposal: proposal(
                additions: [addition(title: "Shadow a dialogue")],
                order: [pendingA.uuidString, pendingB.uuidString, "new-1"]
            )
        )

        #expect(preview.after.tasks[0].details == "Say hello clearly")
        #expect(preview.after.tasks.last?.title == "Shadow a dialogue")
        #expect(preview.after.tasks.last?.details == nil)
    }

    @Test
    func rejectsSearchQueriesThatCopyTheTaskTitle() {
        let before = pendingSnapshot()

        #expect(throws: PlanRefinementValidationError.searchQueryCopiesTitle) {
            _ = try makePreview(
                snapshot: before,
                includesResourceSuggestions: true,
                proposal: proposal(
                    additions: [
                        addition(title: "Shadow a dialogue", searchQuery: "Shadow a dialogue")
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString, "new-1"]
                )
            )
        }
        #expect(throws: PlanRefinementValidationError.searchQueryCopiesTitle) {
            _ = try makePreview(
                snapshot: before,
                includesResourceSuggestions: true,
                proposal: proposal(
                    updates: [
                        PlanRefinementUpdate(
                            taskID: pendingA.uuidString,
                            title: "Practice hola",
                            details: "Say hello clearly",
                            estimatedPomodoros: 1,
                            searchQuery: "Practice hola"
                        )
                    ],
                    order: [pendingA.uuidString, pendingB.uuidString]
                )
            )
        }
    }

    @Test
    func allowsAnUnchangedLegacyQueryThatCopiesTheTitle() throws {
        let before = PlanSnapshot(
            id: planID,
            title: "Spanish greetings",
            details: "A short speaking plan.",
            status: .active,
            tasks: [
                TaskSnapshot(
                    id: pendingA,
                    title: "Practice hola",
                    details: "Say hello clearly",
                    position: 0,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: "Practice hola"
                )
            ]
        )
        let preview = try makePreview(
            snapshot: before,
            includesResourceSuggestions: true,
            proposal: proposal(
                updates: [
                    PlanRefinementUpdate(
                        taskID: pendingA.uuidString,
                        title: "Practice hola and adios",
                        details: "Say hello clearly",
                        estimatedPomodoros: 2,
                        searchQuery: "Practice hola"
                    )
                ],
                order: [pendingA.uuidString]
            )
        )

        #expect(preview.after.tasks[0].searchQuery == "Practice hola")
        #expect(preview.after.tasks[0].title == "Practice hola and adios")
        #expect(preview.after.tasks[0].details == "Say hello clearly")
    }

    @Test
    func keepsAnOptInResourceQueryOnANewTask() throws {
        let before = pendingSnapshot()
        let preview = try makePreview(
            snapshot: before,
            includesResourceSuggestions: true,
            proposal: proposal(
                additions: [
                    addition(title: "Shadow a dialogue", searchQuery: "focused speaking practice")
                ],
                order: [pendingA.uuidString, pendingB.uuidString, "new-1"]
            )
        )

        #expect(preview.after.tasks.last?.searchQuery == "focused speaking practice")
    }

    @Test
    func rejectsTooManyOperationsAndTooManyTasks() {
        let before = pendingSnapshot()
        let additions = (1...9).map { index in
            addition(localID: "new-\(index)", title: "Task \(index)")
        }
        var order = [pendingA.uuidString, pendingB.uuidString]
        order.append(contentsOf: (1...9).map { "new-\($0)" })

        #expect(throws: PlanRefinementValidationError.tooManyOperations) {
            _ = try makePreview(
                snapshot: before,
                proposal: proposal(additions: additions, order: order)
            )
        }

        let eightPending = PlanSnapshot(
            id: planID,
            title: "Spanish greetings",
            details: nil,
            status: .active,
            tasks: (0..<8).map { index in
                TaskSnapshot(
                    id: UUID(uuidString: String(format: "00000000-0000-4000-8000-00000000%04d", index + 1))!,
                    title: "Task \(index + 1)",
                    details: nil,
                    position: index,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: nil
                )
            }
        )
        let ids = eightPending.tasks.map(\.id.uuidString)
        #expect(throws: PlanRefinementValidationError.tooManyTasks) {
            _ = try makePreview(
                snapshot: eightPending,
                proposal: proposal(
                    additions: [addition(title: "Ninth")],
                    order: ids + ["new-1"]
                )
            )
        }
    }

    private func makePreview(
        snapshot: PlanSnapshot,
        includesResourceSuggestions: Bool = false,
        proposal: PlanRefinementProposal
    ) throws -> PlanRefinementPreview {
        try PlanRefinementPreviewFactory.make(
            snapshot: snapshot,
            request: "Add speaking exercises",
            proposal: proposal,
            includesResourceSuggestions: includesResourceSuggestions,
            makeID: { newID }
        )
    }

    private func proposal(
        summary: String = "Refine the plan.",
        additions: [PlanRefinementAddition] = [],
        updates: [PlanRefinementUpdate] = [],
        archived: [String] = [],
        order: [String]
    ) -> PlanRefinementProposal {
        PlanRefinementProposal(
            changeSummary: summary,
            additions: additions,
            updates: updates,
            archivedTaskIDs: archived,
            pendingTaskOrder: order
        )
    }

    private func addition(
        localID: String = "new-1",
        title: String,
        estimatedPomodoros: Int = 1,
        searchQuery: String = ""
    ) -> PlanRefinementAddition {
        PlanRefinementAddition(
            localID: localID,
            title: title,
            details: "",
            estimatedPomodoros: estimatedPomodoros,
            searchQuery: searchQuery
        )
    }

    private func pendingSnapshot() -> PlanSnapshot {
        PlanSnapshot(
            id: planID,
            title: "Spanish greetings",
            details: "A short speaking plan.",
            status: .active,
            tasks: [
                TaskSnapshot(
                    id: pendingA,
                    title: "Practice hola",
                    details: "Say hello clearly",
                    position: 0,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: "Spanish greetings audio"
                ),
                TaskSnapshot(
                    id: pendingB,
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

    private func mixedSnapshot() -> PlanSnapshot {
        PlanSnapshot(
            id: planID,
            title: "Spanish greetings",
            details: "A short speaking plan.",
            status: .active,
            tasks: [
                TaskSnapshot(
                    id: pendingA,
                    title: "Practice hola",
                    details: nil,
                    position: 0,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: nil
                ),
                TaskSnapshot(
                    id: completedC,
                    title: "Record a greeting",
                    details: nil,
                    position: 1,
                    estimatedPomodoros: 1,
                    status: .completed,
                    searchQuery: nil
                ),
                TaskSnapshot(
                    id: pendingB,
                    title: "Review phrases",
                    details: nil,
                    position: 2,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: nil
                ),
                TaskSnapshot(
                    id: activeD,
                    title: "Live conversation",
                    details: nil,
                    position: 3,
                    estimatedPomodoros: 2,
                    status: .active,
                    searchQuery: nil
                ),
                TaskSnapshot(
                    id: pendingE,
                    title: "Read a dialogue",
                    details: nil,
                    position: 4,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: nil
                ),
            ]
        )
    }
}
