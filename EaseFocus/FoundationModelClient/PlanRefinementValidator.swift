import Foundation

nonisolated enum PlanRefinementPreviewFactory {
    static func validatedRequest(_ request: String) throws -> String {
        let trimmed = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PlanRefinementValidationError.emptyRequest
        }
        guard trimmed.count <= PlanRefinementLimits.maximumRequestLength else {
            throw PlanRefinementValidationError.requestTooLong
        }
        return trimmed
    }

    static func make(
        snapshot: PlanSnapshot,
        request: String,
        proposal: PlanRefinementProposal,
        includesResourceSuggestions: Bool,
        makeID: () -> UUID = { UUID() }
    ) throws -> PlanRefinementPreview {
        let trimmedRequest = try validatedRequest(request)
        let before: PlanSnapshot
        do {
            before = try snapshot.validated()
        } catch {
            throw PlanRefinementValidationError.malformedSnapshot
        }

        let after = try PlanRefinementValidator.afterSnapshot(
            from: before,
            proposal: proposal,
            includesResourceSuggestions: includesResourceSuggestions,
            makeID: makeID
        )

        return PlanRefinementPreview(
            request: trimmedRequest,
            changeSummary: try PlanRefinementValidator.validatedChangeSummary(proposal.changeSummary),
            before: before,
            after: after
        )
    }
}

nonisolated enum PlanRefinementValidator {
    static func afterSnapshot(
        from before: PlanSnapshot,
        proposal: PlanRefinementProposal,
        includesResourceSuggestions: Bool,
        makeID: () -> UUID
    ) throws -> PlanSnapshot {
        let changeSummary = try validatedChangeSummary(proposal.changeSummary)
        _ = changeSummary

        let mutationCount = proposal.additions.count
            + proposal.updates.count
            + proposal.archivedTaskIDs.count
        guard mutationCount <= PlanRefinementLimits.maximumOperationCount else {
            throw PlanRefinementValidationError.tooManyOperations
        }

        let tasksByID = Dictionary(uniqueKeysWithValues: before.tasks.map { ($0.id, $0) })
        guard tasksByID.count == before.tasks.count else {
            throw PlanRefinementValidationError.malformedSnapshot
        }

        let additions = try validatedAdditions(
            proposal.additions,
            existingIDs: Set(tasksByID.keys),
            includesResourceSuggestions: includesResourceSuggestions,
            makeID: makeID
        )
        let archivedIDs = try validatedArchiveIDs(proposal.archivedTaskIDs, tasksByID: tasksByID)
        let updatesByID = try validatedUpdates(
            proposal.updates,
            tasksByID: tasksByID,
            archivedIDs: archivedIDs,
            includesResourceSuggestions: includesResourceSuggestions
        )

        let survivingPending = before.tasks.filter { task in
            task.status == .pending && !archivedIDs.contains(task.id)
        }
        let orderedPending = try orderedPendingTasks(
            tokens: proposal.pendingTaskOrder,
            survivingPending: survivingPending,
            additions: additions,
            updatesByID: updatesByID,
            archivedIDs: archivedIDs,
            tasksByID: tasksByID,
            includesResourceSuggestions: includesResourceSuggestions
        )

        let assembled = assemble(
            before: before,
            archivedIDs: archivedIDs,
            orderedPending: orderedPending
        )
        let reindexed = reindexed(assembled)
        let after = PlanSnapshot(
            id: before.id,
            title: before.title,
            details: before.details,
            status: before.status,
            tasks: reindexed
        )
        let validatedAfter: PlanSnapshot
        do {
            validatedAfter = try after.validated()
        } catch {
            throw PlanRefinementValidationError.malformedSnapshot
        }

        try PlanRevisionFactory.preserveCompletedWork(from: before, to: validatedAfter)
        try preserveProtectedWork(from: before, to: validatedAfter)

        let beforeNonArchived = before.tasks.filter { $0.status != .archived }.count
        let afterNonArchived = validatedAfter.tasks.filter { $0.status != .archived }.count
        let taskCap = max(PlanRefinementLimits.maximumTaskCount, beforeNonArchived)
        guard afterNonArchived <= taskCap else {
            throw PlanRefinementValidationError.tooManyTasks
        }

        if validatedAfter.tasks == before.tasks {
            throw PlanRefinementValidationError.noChanges
        }

        return validatedAfter
    }

    static func validatedChangeSummary(_ summary: String) throws -> String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PlanRefinementValidationError.emptyChangeSummary
        }
        guard trimmed.count <= PlanRefinementLimits.maximumSummaryLength else {
            throw PlanRefinementValidationError.textTooLong
        }
        guard !containsURLLikeContent(trimmed) else {
            throw PlanRefinementValidationError.urlLikeContent
        }
        return trimmed
    }

    static func preserveProtectedWork(from before: PlanSnapshot, to after: PlanSnapshot) throws {
        let afterByID = Dictionary(uniqueKeysWithValues: after.tasks.map { ($0.id, $0) })
        for task in before.tasks {
            guard let preserved = afterByID[task.id] else {
                throw PlanRefinementValidationError.malformedSnapshot
            }
            switch task.status {
            case .completed, .active, .archived:
                guard preserved.matchesProtectedWork(task) else {
                    throw PlanRefinementValidationError.protectedTaskReferenced
                }
            case .pending:
                if preserved.status == .archived {
                    guard preserved.title == task.title,
                          preserved.details == task.details,
                          preserved.estimatedPomodoros == task.estimatedPomodoros,
                          preserved.searchQuery == task.searchQuery
                    else {
                        throw PlanRefinementValidationError.protectedTaskReferenced
                    }
                }
            }
        }
    }

    private static func validatedAdditions(
        _ additions: [PlanRefinementAddition],
        existingIDs: Set<UUID>,
        includesResourceSuggestions: Bool,
        makeID: () -> UUID
    ) throws -> [String: TaskSnapshot] {
        var result: [String: TaskSnapshot] = [:]
        var assignedIDs: Set<UUID> = []
        for addition in additions {
            let localID = try validatedLocalID(addition.localID)
            guard result[localID] == nil else {
                throw PlanRefinementValidationError.duplicateOperation
            }
            let title = try validatedTitle(addition.title)
            let details = try validatedDetails(addition.details)
            guard PlanRefinementLimits.pomodoroRange.contains(addition.estimatedPomodoros) else {
                throw PlanRefinementValidationError.invalidPomodoroEstimate
            }
            let query = try resolvedSearchQuery(
                proposed: addition.searchQuery,
                original: nil,
                includesResourceSuggestions: includesResourceSuggestions
            )
            let id = makeID()
            guard !existingIDs.contains(id), assignedIDs.insert(id).inserted else {
                throw PlanRefinementValidationError.duplicateOperation
            }
            result[localID] = TaskSnapshot(
                id: id,
                title: title,
                details: details,
                position: 0,
                estimatedPomodoros: addition.estimatedPomodoros,
                status: .pending,
                searchQuery: query
            )
        }
        return result
    }

    private static func validatedArchiveIDs(
        _ rawIDs: [String],
        tasksByID: [UUID: TaskSnapshot]
    ) throws -> Set<UUID> {
        var archived: Set<UUID> = []
        for raw in rawIDs {
            let id = try parseExistingTaskID(raw)
            guard let task = tasksByID[id] else {
                throw PlanRefinementValidationError.unknownTaskID
            }
            guard task.status == .pending else {
                throw PlanRefinementValidationError.protectedTaskReferenced
            }
            guard archived.insert(id).inserted else {
                throw PlanRefinementValidationError.duplicateOperation
            }
        }
        return archived
    }

    private static func validatedUpdates(
        _ updates: [PlanRefinementUpdate],
        tasksByID: [UUID: TaskSnapshot],
        archivedIDs: Set<UUID>,
        includesResourceSuggestions: Bool
    ) throws -> [UUID: PlanRefinementUpdate] {
        var result: [UUID: PlanRefinementUpdate] = [:]
        for update in updates {
            let id = try parseExistingTaskID(update.taskID)
            guard let task = tasksByID[id] else {
                throw PlanRefinementValidationError.unknownTaskID
            }
            guard task.status == .pending else {
                throw PlanRefinementValidationError.protectedTaskReferenced
            }
            guard !archivedIDs.contains(id) else {
                throw PlanRefinementValidationError.conflictingOperations
            }
            guard result[id] == nil else {
                throw PlanRefinementValidationError.duplicateOperation
            }
            _ = try validatedTitle(update.title)
            _ = try validatedDetails(update.details)
            guard PlanRefinementLimits.pomodoroRange.contains(update.estimatedPomodoros) else {
                throw PlanRefinementValidationError.invalidPomodoroEstimate
            }
            _ = try resolvedSearchQuery(
                proposed: update.searchQuery,
                original: task.searchQuery,
                includesResourceSuggestions: includesResourceSuggestions
            )
            result[id] = update
        }
        return result
    }

    private static func orderedPendingTasks(
        tokens: [String],
        survivingPending: [TaskSnapshot],
        additions: [String: TaskSnapshot],
        updatesByID: [UUID: PlanRefinementUpdate],
        archivedIDs: Set<UUID>,
        tasksByID: [UUID: TaskSnapshot],
        includesResourceSuggestions: Bool
    ) throws -> [TaskSnapshot] {
        var seenTokens: Set<String> = []
        var ordered: [TaskSnapshot] = []
        var seenSurviving: Set<UUID> = []

        for token in tokens {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard seenTokens.insert(trimmed).inserted else {
                throw PlanRefinementValidationError.duplicateInOrdering
            }

            if let addition = additions[trimmed] {
                ordered.append(addition)
                continue
            }

            guard let id = UUID(uuidString: trimmed) else {
                throw PlanRefinementValidationError.malformedTaskID
            }
            guard let task = tasksByID[id] else {
                throw PlanRefinementValidationError.unknownTaskID
            }
            guard task.status == .pending else {
                throw PlanRefinementValidationError.protectedTaskReferenced
            }
            guard !archivedIDs.contains(id) else {
                throw PlanRefinementValidationError.conflictingOperations
            }
            guard seenSurviving.insert(id).inserted else {
                throw PlanRefinementValidationError.duplicateInOrdering
            }

            if let update = updatesByID[id] {
                ordered.append(
                    TaskSnapshot(
                        id: task.id,
                        title: try validatedTitle(update.title),
                        details: try validatedDetails(update.details),
                        position: 0,
                        estimatedPomodoros: update.estimatedPomodoros,
                        status: .pending,
                        searchQuery: try resolvedSearchQuery(
                            proposed: update.searchQuery,
                            original: task.searchQuery,
                            includesResourceSuggestions: includesResourceSuggestions
                        )
                    )
                )
            } else {
                ordered.append(task)
            }
        }

        let missingAdditions = Set(additions.keys).subtracting(seenTokens)
        guard missingAdditions.isEmpty else {
            throw PlanRefinementValidationError.missingFromOrdering
        }

        let survivingIDs = Set(survivingPending.map(\.id))
        guard seenSurviving == survivingIDs else {
            throw PlanRefinementValidationError.missingFromOrdering
        }

        return ordered
    }

    private static func assemble(
        before: PlanSnapshot,
        archivedIDs: Set<UUID>,
        orderedPending: [TaskSnapshot]
    ) -> [TaskSnapshot] {
        var pendingIterator = orderedPending.makeIterator()
        var assembled: [TaskSnapshot] = []
        for task in before.tasks {
            if task.status != .pending {
                assembled.append(task)
            } else if archivedIDs.contains(task.id) {
                var archived = task
                archived.status = .archived
                assembled.append(archived)
            } else if let next = pendingIterator.next() {
                assembled.append(next)
            }
        }
        while let next = pendingIterator.next() {
            assembled.append(next)
        }
        return assembled
    }

    private static func reindexed(_ tasks: [TaskSnapshot]) -> [TaskSnapshot] {
        tasks.enumerated().map { index, task in
            var copy = task
            copy.position = index
            return copy
        }
    }

    private static func validatedLocalID(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= PlanRefinementLimits.maximumLocalIDLength else {
            throw PlanRefinementValidationError.malformedTaskID
        }
        guard UUID(uuidString: trimmed) == nil else {
            throw PlanRefinementValidationError.malformedTaskID
        }
        guard !containsURLLikeContent(trimmed) else {
            throw PlanRefinementValidationError.urlLikeContent
        }
        return trimmed
    }

    private static func parseExistingTaskID(_ raw: String) throws -> UUID {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = UUID(uuidString: trimmed) else {
            throw PlanRefinementValidationError.malformedTaskID
        }
        return id
    }

    private static func validatedTitle(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PlanRefinementValidationError.emptyTaskTitle
        }
        guard trimmed.count <= PlanRefinementLimits.maximumTitleLength else {
            throw PlanRefinementValidationError.textTooLong
        }
        guard !containsURLLikeContent(trimmed) else {
            throw PlanRefinementValidationError.urlLikeContent
        }
        return trimmed
    }

    private static func validatedDetails(_ raw: String) throws -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        guard trimmed.count <= PlanRefinementLimits.maximumDetailsLength else {
            throw PlanRefinementValidationError.textTooLong
        }
        guard !containsURLLikeContent(trimmed) else {
            throw PlanRefinementValidationError.urlLikeContent
        }
        return trimmed
    }

    private static func resolvedSearchQuery(
        proposed: String,
        original: String?,
        includesResourceSuggestions: Bool
    ) throws -> String? {
        let trimmed = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        if !includesResourceSuggestions {
            guard trimmed.isEmpty else {
                throw PlanRefinementValidationError.resourceQueryWhenDisabled
            }
            return original
        }

        switch SearchQueryValidator.validateOptional(proposed) {
        case .success(let query):
            return query
        case .failure(let error):
            throw PlanRefinementValidationError.invalidSearchQuery(error)
        }
    }

    private static func containsURLLikeContent(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("http://")
            || lowered.contains("https://")
            || lowered.contains("www.")
    }
}
