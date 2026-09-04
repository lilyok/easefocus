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
        let changeSummary = try PlanRefinementValidator.validatedChangeSummary(proposal.changeSummary)
        try PlanRefinementValidator.validateAssembledPreview(
            before: before,
            after: after,
            changeSummary: changeSummary
        )

        return PlanRefinementPreview(
            request: trimmedRequest,
            changeSummary: changeSummary,
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
        try validateStatusTransitions(from: before, to: validatedAfter)
        try validateMutableTaskContent(from: before, to: validatedAfter)

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

    static func validateAssembledPreview(
        before: PlanSnapshot,
        after: PlanSnapshot,
        changeSummary: String
    ) throws {
        let validatedBefore: PlanSnapshot
        let validatedAfter: PlanSnapshot
        do {
            validatedBefore = try before.validated()
            validatedAfter = try after.validated()
        } catch {
            throw PlanRefinementValidationError.malformedSnapshot
        }

        _ = try validatedChangeSummary(changeSummary)

        guard validatedAfter.id == validatedBefore.id,
              validatedAfter.title == validatedBefore.title,
              validatedAfter.details == validatedBefore.details,
              validatedAfter.status == validatedBefore.status
        else {
            throw PlanRefinementValidationError.malformedSnapshot
        }

        let beforeIDs = Set(validatedBefore.tasks.map(\.id))
        let afterIDs = Set(validatedAfter.tasks.map(\.id))
        guard beforeIDs.isSubset(of: afterIDs) else {
            throw PlanRefinementValidationError.malformedSnapshot
        }

        try PlanRevisionFactory.preserveCompletedWork(from: validatedBefore, to: validatedAfter)
        try preserveProtectedWork(from: validatedBefore, to: validatedAfter)
        try validateStatusTransitions(from: validatedBefore, to: validatedAfter)
        try validateMutableTaskContent(from: validatedBefore, to: validatedAfter)

        let beforeNonArchived = validatedBefore.tasks.filter { $0.status != .archived }.count
        let afterNonArchived = validatedAfter.tasks.filter { $0.status != .archived }.count
        let taskCap = max(PlanRefinementLimits.maximumTaskCount, beforeNonArchived)
        guard afterNonArchived <= taskCap else {
            throw PlanRefinementValidationError.tooManyTasks
        }
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

    static func validateStatusTransitions(from before: PlanSnapshot, to after: PlanSnapshot) throws {
        let beforeByID = Dictionary(uniqueKeysWithValues: before.tasks.map { ($0.id, $0) })
        for task in after.tasks {
            if let original = beforeByID[task.id] {
                if original.status == .pending {
                    guard task.status == .pending || task.status == .archived else {
                        throw PlanRefinementValidationError.protectedTaskReferenced
                    }
                }
            } else if task.status != .pending {
                throw PlanRefinementValidationError.malformedSnapshot
            }
        }
    }

    static func validateMutableTaskContent(from before: PlanSnapshot, to after: PlanSnapshot) throws {
        let beforeByID = Dictionary(uniqueKeysWithValues: before.tasks.map { ($0.id, $0) })
        for task in after.tasks where task.status == .pending {
            _ = try validatedTitle(task.title)
            if let details = task.details {
                _ = try validatedDetails(details)
            }
            guard PlanRefinementLimits.pomodoroRange.contains(task.estimatedPomodoros) else {
                throw PlanRefinementValidationError.invalidPomodoroEstimate
            }
            try validateStoredSearchQuery(
                task.searchQuery,
                title: task.title,
                original: beforeByID[task.id]?.searchQuery
            )
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
                title: title,
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
                title: try validatedTitle(update.title),
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

            ordered.append(
                try applied(
                    update: updatesByID[id],
                    to: task,
                    includesResourceSuggestions: includesResourceSuggestions
                )
            )
        }

        if seenSurviving.isEmpty {
            let listedAdditions = ordered
            ordered = try survivingPending.map { task in
                try applied(
                    update: updatesByID[task.id],
                    to: task,
                    includesResourceSuggestions: includesResourceSuggestions
                )
            }
            seenSurviving = Set(survivingPending.map(\.id))
            ordered.append(contentsOf: listedAdditions)
        } else {
            for task in survivingPending where seenSurviving.insert(task.id).inserted {
                ordered.append(
                    try applied(
                        update: updatesByID[task.id],
                        to: task,
                        includesResourceSuggestions: includesResourceSuggestions
                    )
                )
            }
        }

        for localID in additions.keys.sorted() where seenTokens.insert(localID).inserted {
            if let addition = additions[localID] {
                ordered.append(addition)
            }
        }

        let survivingIDs = Set(survivingPending.map(\.id))
        guard seenSurviving == survivingIDs else {
            throw PlanRefinementValidationError.missingFromOrdering
        }
        guard Set(additions.keys).isSubset(of: seenTokens) else {
            throw PlanRefinementValidationError.missingFromOrdering
        }

        return ordered
    }

    private static func applied(
        update: PlanRefinementUpdate?,
        to task: TaskSnapshot,
        includesResourceSuggestions: Bool
    ) throws -> TaskSnapshot {
        guard let update else {
            return task
        }

        let title = try validatedTitle(update.title)
        let details: String?
        if update.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details = task.details
        } else {
            details = try validatedDetails(update.details)
        }
        return TaskSnapshot(
            id: task.id,
            title: title,
            details: details,
            position: 0,
            estimatedPomodoros: update.estimatedPomodoros,
            status: .pending,
            searchQuery: try resolvedSearchQuery(
                proposed: update.searchQuery,
                original: task.searchQuery,
                title: title,
                includesResourceSuggestions: includesResourceSuggestions
            )
        )
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
        title: String,
        includesResourceSuggestions: Bool
    ) throws -> String? {
        let trimmed = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        if !includesResourceSuggestions {
            return original
        }

        if let original, queriesMatch(trimmed, original) {
            return original
        }

        switch SearchQueryValidator.validateOptional(proposed) {
        case .success(let query):
            if let query, copiesTitle(query, title: title) {
                throw PlanRefinementValidationError.searchQueryCopiesTitle
            }
            return query
        case .failure(let error):
            throw PlanRefinementValidationError.invalidSearchQuery(error)
        }
    }

    private static func validateStoredSearchQuery(
        _ query: String?,
        title: String,
        original: String?
    ) throws {
        guard let query else {
            return
        }
        switch SearchQueryValidator.validate(query) {
        case .failure(let error):
            throw PlanRefinementValidationError.invalidSearchQuery(error)
        case .success(let validated):
            if copiesTitle(validated, title: title), !queriesMatch(validated, original) {
                throw PlanRefinementValidationError.searchQueryCopiesTitle
            }
        }
    }

    private static func copiesTitle(_ query: String, title: String) -> Bool {
        query.compare(
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            options: [.caseInsensitive, .diacriticInsensitive]
        ) == .orderedSame
    }

    private static func queriesMatch(_ lhs: String, _ rhs: String?) -> Bool {
        guard let rhs else {
            return lhs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private static func containsURLLikeContent(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("http://")
            || lowered.contains("https://")
            || lowered.contains("www.")
    }
}
