import Foundation

nonisolated struct PreviewPlanRefinementClient: PlanRefinementGenerating {
    var availability: FoundationModelAvailability = .available
    var makeID: @Sendable () -> UUID = { UUID() }

    func currentAvailability(locale: Locale) -> FoundationModelAvailability {
        _ = locale
        return availability
    }

    func generateRefinementPreview(
        snapshot: PlanSnapshot,
        request: String,
        locale: Locale,
        survey: GoalSurvey?,
        includesResourceSuggestions: Bool
    ) async throws -> PlanRefinementPreview {
        _ = locale
        _ = survey

        guard !Task.isCancelled else {
            throw PlanRefinementGenerationError.cancelled
        }

        let availability = currentAvailability(locale: .current)
        guard availability.allowsGeneration else {
            throw PlanRefinementGenerationError.unavailable(availability)
        }

        let trimmedRequest: String
        do {
            trimmedRequest = try PlanRefinementPreviewFactory.validatedRequest(request)
        } catch let error as PlanRefinementValidationError {
            throw PlanRefinementGenerationError.validation(error)
        }

        let proposal = Self.proposal(
            snapshot: snapshot,
            request: trimmedRequest,
            includesResourceSuggestions: includesResourceSuggestions
        )

        do {
            return try PlanRefinementPreviewFactory.make(
                snapshot: snapshot,
                request: trimmedRequest,
                proposal: proposal,
                includesResourceSuggestions: includesResourceSuggestions,
                makeID: makeID
            )
        } catch let error as PlanRefinementValidationError {
            throw PlanRefinementGenerationError.validation(error)
        }
    }

    static func proposal(
        snapshot: PlanSnapshot,
        request: String,
        includesResourceSuggestions: Bool
    ) -> PlanRefinementProposal {
        let pending = snapshot.tasks.filter { $0.status == .pending }
        var additions: [PlanRefinementAddition] = []
        var updates: [PlanRefinementUpdate] = []
        var order = pending.map(\.id.uuidString)

        if let first = pending.first {
            updates.append(
                PlanRefinementUpdate(
                    taskID: first.id.uuidString,
                    title: first.title,
                    details: clamped(
                        "Adjusted for: \(request)",
                        maxLength: PlanRefinementLimits.maximumDetailsLength
                    ),
                    estimatedPomodoros: first.estimatedPomodoros,
                    searchQuery: includesResourceSuggestions ? (first.searchQuery ?? "") : ""
                )
            )
        }

        let nonArchivedCount = snapshot.tasks.filter { $0.status != .archived }.count
        let taskCap = max(PlanRefinementLimits.maximumTaskCount, nonArchivedCount)
        if nonArchivedCount < taskCap {
            let title = clamped(
                "Practice: \(request)",
                maxLength: PlanRefinementLimits.maximumTitleLength
            )
            additions.append(
                PlanRefinementAddition(
                    localID: "new-1",
                    title: title.isEmpty ? "Practice the next speaking drill" : title,
                    details: "",
                    estimatedPomodoros: 1,
                    searchQuery: includesResourceSuggestions ? "focused speaking practice" : ""
                )
            )
            order.append("new-1")
        }

        return PlanRefinementProposal(
            changeSummary: "Update the plan for this request without changing completed work.",
            additions: additions,
            updates: updates,
            archivedTaskIDs: [],
            pendingTaskOrder: order
        )
    }

    private static func clamped(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else {
            return trimmed
        }
        return String(trimmed.prefix(maxLength))
    }
}
