import Foundation
import SwiftData

nonisolated enum PlanRefinementChangeKind: Equatable, Sendable {
    case protected
    case unchanged
    case added
    case updated
    case archived
    case reordered
}

nonisolated struct PlanRefinementDisplayedTask: Equatable, Identifiable, Sendable {
    var before: TaskSnapshot?
    var after: TaskSnapshot
    var kind: PlanRefinementChangeKind

    var id: UUID { after.id }
}

nonisolated enum PlanRefinementPresentation {
    static func showsRefineAction(
        planStatus: PlanStatus,
        availability: FoundationModelAvailability
    ) -> Bool {
        planStatus == .active && availability.allowsGeneration
    }

    static func requestError(
        for request: String,
        hasAttemptedGenerate: Bool
    ) -> String? {
        do {
            _ = try PlanRefinementPreviewFactory.validatedRequest(request)
            return nil
        } catch PlanRefinementValidationError.emptyRequest {
            return hasAttemptedGenerate ? PlanRefinementCopy.emptyRequest : nil
        } catch PlanRefinementValidationError.requestTooLong {
            return PlanRefinementCopy.requestTooLong
        } catch {
            return nil
        }
    }

    static func includesResourceSuggestions(survey: GoalSurvey?) -> Bool {
        survey?.includesResourceSuggestions ?? false
    }

    static func isStale(current: PlanSnapshot, preview: PlanRefinementPreview) -> Bool {
        do {
            return try current.validated() != preview.before
        } catch {
            return true
        }
    }

    static func displayedTasks(for preview: PlanRefinementPreview) -> [PlanRefinementDisplayedTask] {
        let beforeByID = Dictionary(uniqueKeysWithValues: preview.before.tasks.map { ($0.id, $0) })
        let beforePendingIDs = preview.before.tasks.filter { $0.status == .pending }.map(\.id)
        let afterPendingIDs = preview.after.tasks.filter { $0.status == .pending }.map(\.id)
        let survivingBefore = beforePendingIDs.filter { afterPendingIDs.contains($0) }
        let survivingAfter = afterPendingIDs.filter { beforePendingIDs.contains($0) }

        return preview.after.tasks
            .sorted { $0.position < $1.position }
            .map { afterTask in
                let beforeTask = beforeByID[afterTask.id]
                return PlanRefinementDisplayedTask(
                    before: beforeTask,
                    after: afterTask,
                    kind: changeKind(
                        before: beforeTask,
                        after: afterTask,
                        survivingBefore: survivingBefore,
                        survivingAfter: survivingAfter
                    )
                )
            }
    }

    static func beforeTasks(for preview: PlanRefinementPreview) -> [TaskSnapshot] {
        preview.before.tasks.sorted { $0.position < $1.position }
    }

    private static func changeKind(
        before: TaskSnapshot?,
        after: TaskSnapshot,
        survivingBefore: [UUID],
        survivingAfter: [UUID]
    ) -> PlanRefinementChangeKind {
        guard let before else {
            return .added
        }

        if before.status == .completed || before.status == .active || before.status == .archived {
            return .protected
        }

        if before.status == .pending, after.status == .archived {
            return .archived
        }

        if before.status == .pending, after.status == .pending {
            let contentChanged = before.title != after.title
                || before.details != after.details
                || before.estimatedPomodoros != after.estimatedPomodoros
                || before.searchQuery != after.searchQuery
            if contentChanged {
                return .updated
            }
            if survivingBefore.firstIndex(of: after.id) != survivingAfter.firstIndex(of: after.id) {
                return .reordered
            }
            return .unchanged
        }

        return .unchanged
    }
}

nonisolated enum PlanRefinementAccessibilityIdentifier {
    static let refineAction = "refinePlan"
    static let request = "refinePlanRequest"
    static let generate = "generateRefinement"
    static let cancel = "cancelRefinement"
    static let confirm = "confirmRefinement"
    static let discard = "discardRefinement"
}

nonisolated enum PlanRefinementCopy {
    static let refineAction = "Refine plan"
    static let requestTitle = "Refine plan"
    static let previewTitle = "Review changes"
    static let requestPrompt = "What should change?"
    static let examples = "Examples: reduce weekly workload, add speaking exercises, adapt to a new deadline, or break a hard task into smaller steps."
    static let protectedExplanation = "Completed and currently active tasks will not change. Focus sessions stay as they are."
    static let generating = "Generating a preview…"
    static let generate = "Generate preview"
    static let generateAgain = "Generate again"
    static let cancel = "Cancel"
    static let stop = "Stop"
    static let confirm = "Confirm"
    static let discard = "Discard"
    static let staleTitle = "This plan has changed"
    static let staleMessage = "The plan was edited after this preview was created. Generate again to review a new preview."
    static let emptyRequest = "Enter a short request, such as add speaking exercises."
    static let requestTooLong = "Keep the request to \(PlanRefinementLimits.maximumRequestLength) characters or fewer."
    static let malformedApply = "Couldn't apply this preview. Generate again or edit the plan manually."
    static let beforeSection = "Before"
    static let afterSection = "After"

    static func badge(for kind: PlanRefinementChangeKind) -> String? {
        switch kind {
        case .added:
            return "Added"
        case .updated:
            return "Updated"
        case .archived:
            return "Archived"
        case .reordered:
            return "Moved"
        case .protected, .unchanged:
            return nil
        }
    }

    static func statusLabel(for status: TaskStatus) -> String? {
        switch status {
        case .completed:
            return "Completed"
        case .active:
            return "In progress"
        case .archived:
            return "Archived"
        case .pending:
            return nil
        }
    }
}

nonisolated enum PlanRefinementGenerationErrorCopy {
    static func message(for error: PlanRefinementGenerationError) -> String {
        switch error {
        case .unavailable(let availability):
            return FoundationModelAvailabilityCopy.message(for: availability)
        case .validation(let reason):
            return validationMessage(for: reason)
        case .refusal:
            return "Apple Intelligence declined this request. Rephrase it and try again."
        case .guardrailViolation:
            return "Apple Intelligence blocked this request for safety. Adjust the request and try again."
        case .unsupportedLanguageOrLocale:
            return "Apple Intelligence cannot refine this plan in this language. Choose a supported language or edit the plan manually."
        case .contextLimitExceeded:
            return "The request is too long for Apple Intelligence. Shorten it and try again."
        case .generationFailed:
            return "Couldn't generate a refinement. You can try again or keep editing the plan manually."
        case .cancelled:
            return ""
        }
    }

    static func validationMessage(for error: PlanRefinementValidationError) -> String {
        switch error {
        case .emptyRequest:
            return PlanRefinementCopy.emptyRequest
        case .requestTooLong:
            return PlanRefinementCopy.requestTooLong
        default:
            return "The generated preview wasn't valid. Rephrase the request and try again, or keep editing the plan manually."
        }
    }
}

nonisolated enum PlanRefinementConfirmResult: Equatable {
    case applied
    case stale
    case saveFailed
    case malformed
}

enum PlanRefinementConfirming {
    @MainActor
    static func apply(
        _ preview: PlanRefinementPreview,
        to plan: GoalPlan,
        in context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) -> PlanRefinementConfirmResult {
        let current: PlanSnapshot
        do {
            current = try PlanSnapshot.capturing(plan).validated()
        } catch {
            return .malformed
        }

        guard !PlanRefinementPresentation.isStale(current: current, preview: preview) else {
            return .stale
        }

        do {
            try PlanRefinementApplier.apply(preview, to: plan, in: context, save: save)
            return .applied
        } catch PlanRefinementApplierError.stalePreview {
            return .stale
        } catch PlanRefinementApplierError.saveFailed {
            return .saveFailed
        } catch {
            return .malformed
        }
    }
}
