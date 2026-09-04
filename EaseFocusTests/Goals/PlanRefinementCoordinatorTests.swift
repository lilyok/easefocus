import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct PlanRefinementCoordinatorTests {
    private enum SampleError: Error {
        case diskFull
    }

    private let firstAddedID = UUID(uuidString: "00000000-0000-4000-8000-00000000add1")!
    private let secondAddedID = UUID(uuidString: "00000000-0000-4000-8000-00000000add2")!

    @Test
    @MainActor
    func emptyRequestsFailInlineWithoutGenerating() async throws {
        let (plan, _, container) = try makePlan()
        _ = container
        let coordinator = PlanRefinementCoordinator()
        let client = PreviewPlanRefinementClient()

        coordinator.generate(plan: plan, client: client, locale: Locale(identifier: "en"))

        #expect(coordinator.hasAttemptedGenerate)
        #expect(coordinator.requestError == PlanRefinementCopy.emptyRequest)
        #expect(!coordinator.isGenerating)
        #expect(coordinator.preview == nil)
        #expect(plan.revisions.isEmpty)
    }

    @Test
    @MainActor
    func generatingAPreviewDoesNotMutateSwiftData() async throws {
        let (plan, context, container) = try makePlan()
        _ = container
        let before = PlanSnapshot.capturing(plan)
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { firstAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }

        #expect(coordinator.preview != nil)
        #expect(coordinator.preview?.changeSummary.isEmpty == false)
        #expect(!coordinator.didApply)
        #expect(!context.hasChanges)
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.revisions.isEmpty)
        #expect(plan.orderedTasks.map(\.title) == ["Practice hola", "Record a greeting"])
    }

    @Test
    @MainActor
    func passesLocaleSurveyAndResourcePreferenceAtRequestTime() async throws {
        var survey = GoalSurvey(goal: "Learn Spanish greetings")
        survey.includesResourceSuggestions = true
        let (plan, _, container) = try makePlan(survey: survey)
        _ = container
        let record = GenerationRecord()
        let locale = Locale(identifier: "en_GB")
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "  Add speaking exercises  "
        coordinator.generate(
            plan: plan,
            client: RecordingPreviewPlanRefinementClient(record: record),
            locale: locale
        )
        await waitUntil { !coordinator.isGenerating }

        #expect(record.snapshot == PlanSnapshot.capturing(plan))
        #expect(record.request == "  Add speaking exercises  ")
        #expect(record.localeIdentifier == locale.identifier)
        #expect(record.survey == survey)
        #expect(record.includesResourceSuggestions == true)
    }

    @Test
    @MainActor
    func missingSurveyOptsOutOfResourceSuggestions() async throws {
        let (plan, _, container) = try makePlan(survey: nil)
        _ = container
        let record = GenerationRecord()
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: RecordingPreviewPlanRefinementClient(record: record),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }

        #expect(record.survey == nil)
        #expect(record.includesResourceSuggestions == false)
    }

    @Test
    @MainActor
    func cancellingGenerationLeavesThePlanUnchanged() async throws {
        let (plan, _, container) = try makePlan()
        _ = container
        let before = PlanSnapshot.capturing(plan)
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: DelayedPreviewPlanRefinementClient(delay: .milliseconds(200)),
            locale: Locale(identifier: "en")
        )
        #expect(coordinator.isGenerating)
        coordinator.cancelGeneration()

        #expect(!coordinator.isGenerating)
        try await Task.sleep(for: .milliseconds(300))
        #expect(coordinator.preview == nil)
        #expect(coordinator.generationError == nil)
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.revisions.isEmpty)
    }

    @Test
    @MainActor
    func regeneratingReplacesTheDraftPreviewWithoutMutatingSwiftData() async throws {
        let (plan, context, container) = try makePlan()
        _ = container
        let before = PlanSnapshot.capturing(plan)
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { firstAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }
        let firstPreview = try #require(coordinator.preview)

        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { secondAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }
        let secondPreview = try #require(coordinator.preview)

        #expect(secondPreview != firstPreview)
        #expect(secondPreview.after.tasks.contains { $0.id == secondAddedID })
        #expect(!firstPreview.after.tasks.contains { $0.id == secondAddedID })
        #expect(!context.hasChanges)
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.revisions.isEmpty)
    }

    @Test
    @MainActor
    func failedRegenerateKeepsTheLastPreviewAndBlocksConfirm() async throws {
        let (plan, context, container) = try makePlan()
        _ = container
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { firstAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }
        let firstPreview = try #require(coordinator.preview)
        #expect(coordinator.canConfirm(plan: plan))

        coordinator.generate(
            plan: plan,
            client: FailingPlanRefinementClient(),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }

        #expect(coordinator.preview == firstPreview)
        #expect(coordinator.generationError == PlanRefinementGenerationErrorCopy.message(for: .generationFailed))
        #expect(!coordinator.canConfirm(plan: plan))
        #expect(coordinator.showsPreviousPreviewNotice(plan: plan))

        coordinator.confirm(plan: plan, context: context)

        #expect(!coordinator.didApply)
        #expect(coordinator.preview == firstPreview)
        #expect(plan.revisions.isEmpty)
        #expect(plan.orderedTasks.map(\.title) == ["Practice hola", "Record a greeting"])
    }

    @Test
    @MainActor
    func cancellingARegenerateKeepsTheLastPreview() async throws {
        let (plan, _, container) = try makePlan()
        _ = container
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { firstAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }
        let firstPreview = try #require(coordinator.preview)

        coordinator.generate(
            plan: plan,
            client: DelayedPreviewPlanRefinementClient(delay: .milliseconds(200)),
            locale: Locale(identifier: "en")
        )
        #expect(coordinator.isGenerating)
        #expect(coordinator.preview == firstPreview)
        #expect(!coordinator.canConfirm(plan: plan))
        coordinator.cancelGeneration()

        #expect(!coordinator.isGenerating)
        try await Task.sleep(for: .milliseconds(300))
        #expect(coordinator.preview == firstPreview)
        #expect(coordinator.generationError == nil)
        #expect(coordinator.canConfirm(plan: plan))
        #expect(!coordinator.showsPreviousPreviewNotice(plan: plan))
    }

    @Test
    @MainActor
    func confirmAppliesThroughTheApplierAndRecordsARevision() async throws {
        let (plan, context, container) = try makePlan()
        _ = container
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { firstAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }
        let preview = try #require(coordinator.preview)

        coordinator.confirm(plan: plan, context: context)

        #expect(coordinator.didApply)
        #expect(try PlanSnapshot.capturing(plan).validated() == preview.after)
        #expect(plan.orderedRevisions.count == 1)
        #expect(plan.orderedRevisions.first?.source == .model)
        #expect(plan.orderedRevisions.first?.reason == "Add speaking exercises")
        #expect(plan.orderedRevisions.first?.changeSummary == preview.changeSummary)
        #expect(try plan.orderedRevisions.first?.decodedBeforeSnapshot() == preview.before)
        #expect(try plan.orderedRevisions.first?.decodedAfterSnapshot() == preview.after)
    }

    @Test
    @MainActor
    func discardLeavesThePlanUnchanged() async throws {
        let (plan, _, container) = try makePlan()
        _ = container
        let before = PlanSnapshot.capturing(plan)
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { firstAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }
        #expect(coordinator.preview != nil)

        coordinator.discardPreview()

        #expect(coordinator.preview == nil)
        #expect(!coordinator.didApply)
        #expect(coordinator.request == "Add speaking exercises")
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.revisions.isEmpty)
        #expect(plan.orderedTasks.map(\.title) == ["Practice hola", "Record a greeting"])
    }

    @Test
    @MainActor
    func stalePreviewIsBlockedAndCanGenerateAgain() async throws {
        let (plan, context, container) = try makePlan()
        _ = container
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { firstAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }

        plan.orderedTasks[0].title = "Edited after preview"
        try context.save()
        #expect(coordinator.isStale(plan: plan))

        coordinator.confirm(plan: plan, context: context)

        #expect(!coordinator.didApply)
        #expect(coordinator.generationError == PlanRefinementCopy.staleMessage)
        #expect(plan.revisions.isEmpty)
        #expect(plan.orderedTasks.map(\.title) == ["Edited after preview", "Record a greeting"])

        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { secondAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }

        #expect(!coordinator.isStale(plan: plan))
        #expect(coordinator.preview?.before.tasks.first?.title == "Edited after preview")
        #expect(plan.revisions.isEmpty)
    }

    @Test
    @MainActor
    func failedRegenerateOnAStalePlanKeepsTheGenerateError() async throws {
        let (plan, context, container) = try makePlan()
        _ = container
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { firstAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }

        plan.orderedTasks[0].title = "Edited after preview"
        try context.save()
        #expect(coordinator.isStale(plan: plan))

        coordinator.generate(
            plan: plan,
            client: FailingPlanRefinementClient(),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }

        let failed = PlanRefinementGenerationErrorCopy.message(for: .generationFailed)
        #expect(coordinator.isStale(plan: plan))
        #expect(coordinator.generationError == failed)
        #expect(!coordinator.canConfirm(plan: plan))
        #expect(
            PlanRefinementPresentation.displayedGenerationError(
                isStale: true,
                generationError: coordinator.generationError
            ) == failed
        )
        #expect(plan.revisions.isEmpty)
    }

    @Test
    @MainActor
    func saveFailureSurfacesRetryAndDiscardWithoutASecondRollback() async throws {
        let (plan, context, container) = try makePlan()
        _ = container
        let before = PlanSnapshot.capturing(plan)
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { firstAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }

        var remainingFailures = 1
        let save: (ModelContext) throws -> Void = { context in
            if remainingFailures > 0 {
                remainingFailures -= 1
                throw SampleError.diskFull
            }
            try context.save()
        }

        coordinator.confirm(plan: plan, context: context, save: save)

        #expect(!coordinator.didApply)
        #expect(coordinator.isSaveAlertPresented)
        #expect(coordinator.saveErrorMessage == PersistenceSaveCopy.message)
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.revisions.isEmpty)

        coordinator.discardFailedSave()
        #expect(!coordinator.isSaveAlertPresented)
        #expect(coordinator.saveErrorMessage == nil)
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.revisions.isEmpty)
        #expect(coordinator.preview != nil)

        coordinator.confirm(plan: plan, context: context, save: save)

        #expect(coordinator.didApply)
        #expect(plan.orderedRevisions.count == 1)
        #expect(plan.orderedTasks.contains { $0.id == firstAddedID })
    }

    @Test
    @MainActor
    func retrySaveReappliesAfterAFailedSave() async throws {
        let (plan, context, container) = try makePlan()
        _ = container
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(makeID: { firstAddedID }),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }

        var remainingFailures = 1
        let save: (ModelContext) throws -> Void = { context in
            if remainingFailures > 0 {
                remainingFailures -= 1
                throw SampleError.diskFull
            }
            try context.save()
        }

        coordinator.confirm(plan: plan, context: context, save: save)
        #expect(coordinator.isSaveAlertPresented)
        #expect(plan.revisions.isEmpty)

        coordinator.retrySave()

        #expect(coordinator.didApply)
        #expect(!coordinator.isSaveAlertPresented)
        #expect(plan.orderedRevisions.count == 1)
    }

    @Test
    @MainActor
    func surfacesUnavailableGenerationCopyWithoutApplying() async throws {
        let (plan, _, container) = try makePlan()
        _ = container
        let coordinator = PlanRefinementCoordinator()
        coordinator.request = "Add speaking exercises"
        coordinator.generate(
            plan: plan,
            client: PreviewPlanRefinementClient(availability: .unavailable(.modelNotReady)),
            locale: Locale(identifier: "en")
        )
        await waitUntil { !coordinator.isGenerating }

        #expect(coordinator.preview == nil)
        #expect(
            coordinator.generationError
                == FoundationModelAvailabilityCopy.message(for: .unavailable(.modelNotReady))
        )
        #expect(plan.revisions.isEmpty)
    }

    @Test
    @MainActor
    func confirmingAStalePreviewDoesNotApply() throws {
        let (plan, context, container) = try makePlan()
        _ = container
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
                pendingTaskOrder: [
                    plan.orderedTasks[0].id.uuidString,
                    "new-1",
                ]
            ),
            includesResourceSuggestions: false,
            makeID: { firstAddedID }
        )

        plan.orderedTasks[0].title = "Edited after preview"
        try context.save()

        #expect(PlanRefinementConfirming.apply(preview, to: plan, in: context) == .stale)
        #expect(plan.revisions.isEmpty)
        #expect(plan.orderedTasks.map(\.title) == ["Edited after preview", "Record a greeting"])
    }

    @Test
    @MainActor
    func confirmingSurfacesSaveFailureAndLeavesThePlanUnchanged() throws {
        let (plan, context, container) = try makePlan()
        _ = container
        let before = PlanSnapshot.capturing(plan)
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
                pendingTaskOrder: [
                    plan.orderedTasks[0].id.uuidString,
                    "new-1",
                ]
            ),
            includesResourceSuggestions: false,
            makeID: { firstAddedID }
        )

        #expect(
            PlanRefinementConfirming.apply(
                preview,
                to: plan,
                in: context,
                save: { _ in throw SampleError.diskFull }
            ) == .saveFailed
        )
        #expect(PlanSnapshot.capturing(plan) == before)
        #expect(plan.revisions.isEmpty)
    }

    @MainActor
    private func makePlan(survey: GoalSurvey? = nil) throws -> (GoalPlan, ModelContext, ModelContainer) {
        let container = try EaseFocusStore.inMemoryContainer()
        let context = container.mainContext
        let pending = PlanTask(title: "Practice hola", position: 0)
        let completed = PlanTask(title: "Record a greeting", position: 1, status: .completed)
        let plan = GoalPlan(
            title: "Spanish greetings",
            details: "A short speaking plan.",
            surveySnapshot: survey?.encoded(),
            tasks: [pending, completed]
        )
        context.insert(plan)
        try context.save()
        return (plan, context, container)
    }

    @MainActor
    private func waitUntil(
        _ condition: @MainActor () -> Bool,
        timeout: Duration = .seconds(5)
    ) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Timed out waiting for the refinement coordinator")
    }
}

private final class GenerationRecord: @unchecked Sendable {
    var snapshot: PlanSnapshot?
    var request: String?
    var localeIdentifier: String?
    var survey: GoalSurvey?
    var includesResourceSuggestions: Bool?
}

private struct RecordingPreviewPlanRefinementClient: PlanRefinementGenerating {
    let record: GenerationRecord
    var inner = PreviewPlanRefinementClient()

    func currentAvailability(locale: Locale) -> FoundationModelAvailability {
        inner.currentAvailability(locale: locale)
    }

    func generateRefinementPreview(
        snapshot: PlanSnapshot,
        request: String,
        locale: Locale,
        survey: GoalSurvey?,
        includesResourceSuggestions: Bool
    ) async throws -> PlanRefinementPreview {
        record.snapshot = snapshot
        record.request = request
        record.localeIdentifier = locale.identifier
        record.survey = survey
        record.includesResourceSuggestions = includesResourceSuggestions
        return try await inner.generateRefinementPreview(
            snapshot: snapshot,
            request: request,
            locale: locale,
            survey: survey,
            includesResourceSuggestions: includesResourceSuggestions
        )
    }
}

private struct FailingPlanRefinementClient: PlanRefinementGenerating {
    var error: PlanRefinementGenerationError = .generationFailed

    func currentAvailability(locale: Locale) -> FoundationModelAvailability {
        _ = locale
        return .available
    }

    func generateRefinementPreview(
        snapshot: PlanSnapshot,
        request: String,
        locale: Locale,
        survey: GoalSurvey?,
        includesResourceSuggestions: Bool
    ) async throws -> PlanRefinementPreview {
        _ = snapshot
        _ = request
        _ = locale
        _ = survey
        _ = includesResourceSuggestions
        throw error
    }
}

private struct DelayedPreviewPlanRefinementClient: PlanRefinementGenerating {
    var delay: Duration
    var inner = PreviewPlanRefinementClient()

    func currentAvailability(locale: Locale) -> FoundationModelAvailability {
        inner.currentAvailability(locale: locale)
    }

    func generateRefinementPreview(
        snapshot: PlanSnapshot,
        request: String,
        locale: Locale,
        survey: GoalSurvey?,
        includesResourceSuggestions: Bool
    ) async throws -> PlanRefinementPreview {
        try await Task.sleep(for: delay)
        try Task.checkCancellation()
        return try await inner.generateRefinementPreview(
            snapshot: snapshot,
            request: request,
            locale: locale,
            survey: survey,
            includesResourceSuggestions: includesResourceSuggestions
        )
    }
}
