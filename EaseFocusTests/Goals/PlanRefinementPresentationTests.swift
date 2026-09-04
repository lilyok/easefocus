import Foundation
import Testing
@testable import EaseFocus

struct PlanRefinementPresentationTests {
    private let pendingID = UUID(uuidString: "00000000-0000-4000-8000-00000000000a")!
    private let reviewID = UUID(uuidString: "00000000-0000-4000-8000-00000000000b")!
    private let activeID = UUID(uuidString: "00000000-0000-4000-8000-00000000000c")!
    private let completedID = UUID(uuidString: "00000000-0000-4000-8000-00000000000d")!
    private let addedID = UUID(uuidString: "00000000-0000-4000-8000-00000000add1")!

    @Test
    func hidesRefineWhenFoundationModelsAreUnavailableOrThePlanIsNotActive() {
        #expect(
            PlanRefinementPresentation.showsRefineAction(
                planStatus: .active,
                availability: .available
            )
        )
        #expect(
            !PlanRefinementPresentation.showsRefineAction(
                planStatus: .active,
                availability: .unavailable(.appleIntelligenceNotEnabled)
            )
        )
        #expect(
            !PlanRefinementPresentation.showsRefineAction(
                planStatus: .active,
                availability: .unavailable(.deviceNotEligible)
            )
        )
        #expect(
            !PlanRefinementPresentation.showsRefineAction(
                planStatus: .active,
                availability: .unavailable(.modelNotReady)
            )
        )
        #expect(
            !PlanRefinementPresentation.showsRefineAction(
                planStatus: .active,
                availability: .localeUnsupported(Locale(identifier: "en"))
            )
        )
        #expect(
            !PlanRefinementPresentation.showsRefineAction(
                planStatus: .paused,
                availability: .available
            )
        )
        #expect(
            !PlanRefinementPresentation.showsRefineAction(
                planStatus: .completed,
                availability: .available
            )
        )
        #expect(
            !PlanRefinementPresentation.showsRefineAction(
                planStatus: .archived,
                availability: .available
            )
        )
    }

    @Test
    func validatesRequestsThroughThePreviewFactory() {
        #expect(
            PlanRefinementPresentation.requestError(for: "", hasAttemptedGenerate: false) == nil
        )
        #expect(
            PlanRefinementPresentation.requestError(for: "   ", hasAttemptedGenerate: true)
                == PlanRefinementCopy.emptyRequest
        )
        #expect(
            PlanRefinementPresentation.requestError(
                for: String(repeating: "a", count: PlanRefinementLimits.maximumRequestLength + 1),
                hasAttemptedGenerate: false
            ) == PlanRefinementCopy.requestTooLong
        )
        #expect(
            PlanRefinementPresentation.requestError(
                for: "Add speaking exercises",
                hasAttemptedGenerate: true
            ) == nil
        )
        #expect(
            (try? PlanRefinementPreviewFactory.validatedRequest("Add speaking exercises"))
                == "Add speaking exercises"
        )
    }

    @Test
    func treatsAMissingSurveyAsOptingOutOfResourceSuggestions() {
        #expect(PlanRefinementPresentation.includesResourceSuggestions(survey: nil) == false)
        #expect(
            PlanRefinementPresentation.includesResourceSuggestions(survey: GoalSurvey()) == false
        )
        var survey = GoalSurvey(goal: "Speak more clearly")
        survey.includesResourceSuggestions = true
        #expect(PlanRefinementPresentation.includesResourceSuggestions(survey: survey))
    }

    @Test
    func marksAddedUpdatedArchivedAndReorderedPendingTasks() throws {
        let before = mixedSnapshot()
        let preview = try PlanRefinementPreviewFactory.make(
            snapshot: before,
            request: "Break the hard task into smaller steps",
            proposal: PlanRefinementProposal(
                changeSummary: "Split pending work and archive review.",
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
                        taskID: pendingID.uuidString,
                        title: "Practice hola and adios",
                        details: "",
                        estimatedPomodoros: 1,
                        searchQuery: ""
                    )
                ],
                archivedTaskIDs: [reviewID.uuidString],
                pendingTaskOrder: ["new-1", pendingID.uuidString]
            ),
            includesResourceSuggestions: false,
            makeID: { addedID }
        )

        let displayed = PlanRefinementPresentation.displayedTasks(for: preview)
        let byID = Dictionary(uniqueKeysWithValues: displayed.map { ($0.id, $0) })

        #expect(byID[addedID]?.kind == .added)
        #expect(byID[pendingID]?.kind == .updated)
        #expect(byID[reviewID]?.kind == .archived)
        #expect(byID[activeID]?.kind == .protected)
        #expect(byID[completedID]?.kind == .protected)
        #expect(PlanRefinementCopy.summarySection == "Summary")
        #expect(PlanRefinementCopy.beforeSection == "Before")
        #expect(PlanRefinementCopy.afterSection == "After")
        #expect(PlanRefinementCopy.previousPreviewNotice.contains("last successful preview"))
        #expect(PlanRefinementCopy.badge(for: .added) == "Added")
        #expect(PlanRefinementCopy.badge(for: .updated) == "Updated")
        #expect(PlanRefinementCopy.badge(for: .archived) == "Archived")
        #expect(PlanRefinementCopy.badge(for: .protected) == nil)
        #expect(PlanRefinementCopy.badge(for: .unchanged) == nil)
    }

    @Test
    func marksReorderedPendingTasksWithoutTouchingProtectedWork() throws {
        let before = mixedSnapshot()
        let preview = try PlanRefinementPreviewFactory.make(
            snapshot: before,
            request: "Put review first",
            proposal: PlanRefinementProposal(
                changeSummary: "Move review ahead of the first drill.",
                additions: [],
                updates: [],
                archivedTaskIDs: [],
                pendingTaskOrder: [reviewID.uuidString, pendingID.uuidString]
            ),
            includesResourceSuggestions: false
        )

        let displayed = PlanRefinementPresentation.displayedTasks(for: preview)
        let byID = Dictionary(uniqueKeysWithValues: displayed.map { ($0.id, $0) })

        #expect(byID[pendingID]?.kind == .reordered)
        #expect(byID[reviewID]?.kind == .reordered)
        #expect(byID[activeID]?.kind == .protected)
        #expect(byID[completedID]?.kind == .protected)
        #expect(byID[activeID]?.after.title == "In-progress drill")
        #expect(byID[completedID]?.after.title == "Record a greeting")
        #expect(PlanRefinementCopy.badge(for: .reordered) == "Moved")
        let afterActive = try #require(preview.after.tasks.first { $0.id == activeID })
        let beforeActive = try #require(before.tasks.first { $0.id == activeID })
        #expect(afterActive.matchesProtectedWork(beforeActive))
        let afterCompleted = try #require(preview.after.tasks.first { $0.id == completedID })
        let beforeCompleted = try #require(before.tasks.first { $0.id == completedID })
        #expect(afterCompleted.matchesProtectedWork(beforeCompleted))
    }

    @Test
    func flagsAStalePreviewWhenTheLiveSnapshotDiverges() throws {
        let before = mixedSnapshot()
        let preview = try PlanRefinementPreviewFactory.make(
            snapshot: before,
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
                pendingTaskOrder: [pendingID.uuidString, reviewID.uuidString, "new-1"]
            ),
            includesResourceSuggestions: false,
            makeID: { addedID }
        )

        #expect(!PlanRefinementPresentation.isStale(current: before, preview: preview))

        var changed = before
        changed.tasks[0].title = "Edited after preview"
        #expect(PlanRefinementPresentation.isStale(current: changed, preview: preview))
    }

    @Test
    func blocksConfirmWhileGeneratingOrAfterAFailedRegenerate() {
        #expect(
            PlanRefinementPresentation.canConfirm(
                hasPreview: true,
                isGenerating: false,
                generationError: nil,
                isStale: false
            )
        )
        #expect(
            !PlanRefinementPresentation.canConfirm(
                hasPreview: true,
                isGenerating: true,
                generationError: nil,
                isStale: false
            )
        )
        #expect(
            !PlanRefinementPresentation.canConfirm(
                hasPreview: true,
                isGenerating: false,
                generationError: "Couldn't generate a refinement.",
                isStale: false
            )
        )
        #expect(
            !PlanRefinementPresentation.canConfirm(
                hasPreview: true,
                isGenerating: false,
                generationError: nil,
                isStale: true
            )
        )
        #expect(
            !PlanRefinementPresentation.canConfirm(
                hasPreview: false,
                isGenerating: false,
                generationError: nil,
                isStale: false
            )
        )
    }

    @Test
    func mapsGenerationErrorsToActionableCopy() {
        #expect(
            PlanRefinementGenerationErrorCopy.message(
                for: .unavailable(.unavailable(.appleIntelligenceNotEnabled))
            ) == FoundationModelAvailabilityCopy.message(
                for: .unavailable(.appleIntelligenceNotEnabled)
            )
        )
        #expect(
            PlanRefinementGenerationErrorCopy.message(for: .validation(.emptyRequest))
                == PlanRefinementCopy.emptyRequest
        )
        #expect(
            PlanRefinementGenerationErrorCopy.message(for: .validation(.requestTooLong))
                == PlanRefinementCopy.requestTooLong
        )
        #expect(
            PlanRefinementGenerationErrorCopy.message(for: .validation(.noChanges))
                .contains("already in the plan")
        )
        #expect(
            PlanRefinementGenerationErrorCopy.message(for: .validation(.tooManyOperations))
                .contains("smaller change")
        )
        #expect(PlanRefinementGenerationErrorCopy.message(for: .refusal).contains("declined"))
        #expect(PlanRefinementGenerationErrorCopy.message(for: .guardrailViolation).contains("safety"))
        #expect(
            PlanRefinementGenerationErrorCopy.message(for: .unsupportedLanguageOrLocale)
                .contains("language")
        )
        #expect(
            PlanRefinementGenerationErrorCopy.message(for: .contextLimitExceeded)
                .contains("too long")
        )
        #expect(PlanRefinementGenerationErrorCopy.message(for: .generationFailed).contains("try again"))
        #expect(PlanRefinementGenerationErrorCopy.message(for: .cancelled).isEmpty)
    }

    @Test
    @MainActor
    func defaultEnvironmentClientIsLiveAndPreviewsCanInjectThePreviewClient() {
        #expect((PlanRefinementClientKey.defaultValue as? LivePlanRefinementClient) != nil)
        let previewClient: any PlanRefinementGenerating = PreviewPlanRefinementClient()
        #expect((previewClient as? PreviewPlanRefinementClient) != nil)
        #expect(PlanRefinementAccessibilityIdentifier.refineAction == "refinePlan")
        #expect(PlanRefinementAccessibilityIdentifier.request == "refinePlanRequest")
        #expect(PlanRefinementAccessibilityIdentifier.generate == "generateRefinement")
        #expect(PlanRefinementAccessibilityIdentifier.cancel == "cancelRefinement")
        #expect(PlanRefinementAccessibilityIdentifier.confirm == "confirmRefinement")
        #expect(PlanRefinementAccessibilityIdentifier.discard == "discardRefinement")
    }

    private func mixedSnapshot() -> PlanSnapshot {
        PlanSnapshot(
            id: UUID(uuidString: "00000000-0000-4000-8000-00000000aaaa")!,
            title: "Spanish greetings",
            details: "A short speaking plan.",
            status: .active,
            tasks: [
                TaskSnapshot(
                    id: pendingID,
                    title: "Practice hola",
                    details: nil,
                    position: 0,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: nil
                ),
                TaskSnapshot(
                    id: reviewID,
                    title: "Review phrases",
                    details: nil,
                    position: 1,
                    estimatedPomodoros: 1,
                    status: .pending,
                    searchQuery: nil
                ),
                TaskSnapshot(
                    id: activeID,
                    title: "In-progress drill",
                    details: nil,
                    position: 2,
                    estimatedPomodoros: 1,
                    status: .active,
                    searchQuery: nil
                ),
                TaskSnapshot(
                    id: completedID,
                    title: "Record a greeting",
                    details: nil,
                    position: 3,
                    estimatedPomodoros: 1,
                    status: .completed,
                    searchQuery: nil
                ),
            ]
        )
    }
}
