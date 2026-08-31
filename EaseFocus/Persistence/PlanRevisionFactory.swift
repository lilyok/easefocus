import Foundation

nonisolated enum PlanRevisionFactoryError: Equatable, Error {
    case emptyReason
    case malformedSnapshot
    case duplicateTaskIDs
    case invalidOrdering
    case completedWorkMutated
}

nonisolated enum PlanRevisionFactory {
    static func make(
        for plan: GoalPlan,
        reason: String,
        source: RevisionSource,
        changeSummary: String,
        before: PlanSnapshot,
        after: PlanSnapshot,
        now: Date = .now
    ) throws -> PlanRevision {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else {
            throw PlanRevisionFactoryError.emptyReason
        }

        let validatedBefore: PlanSnapshot
        let validatedAfter: PlanSnapshot
        do {
            validatedBefore = try before.validated()
            validatedAfter = try after.validated()
        } catch let error as PlanRevisionFactoryError {
            throw error
        } catch {
            throw PlanRevisionFactoryError.malformedSnapshot
        }

        guard validatedBefore.id == plan.id, validatedAfter.id == plan.id else {
            throw PlanRevisionFactoryError.malformedSnapshot
        }
        try preserveCompletedWork(from: validatedBefore, to: validatedAfter)

        let beforeData: Data
        let afterData: Data
        do {
            beforeData = try PlanSnapshotCoding.encode(validatedBefore)
            afterData = try PlanSnapshotCoding.encode(validatedAfter)
            _ = try PlanSnapshotCoding.decode(beforeData)
            _ = try PlanSnapshotCoding.decode(afterData)
        } catch {
            throw PlanRevisionFactoryError.malformedSnapshot
        }

        let revision = PlanRevision(
            createdAt: now,
            reason: trimmedReason,
            source: source,
            changeSummary: changeSummary,
            beforeSnapshotData: beforeData,
            afterSnapshotData: afterData
        )
        revision.plan = plan
        return revision
    }

    static func preserveCompletedWork(
        from before: PlanSnapshot,
        to after: PlanSnapshot
    ) throws {
        let afterByID = Dictionary(uniqueKeysWithValues: after.tasks.map { ($0.id, $0) })
        for task in before.tasks where task.status == .completed {
            guard let preserved = afterByID[task.id], preserved.matchesCompletedWork(task) else {
                throw PlanRevisionFactoryError.completedWorkMutated
            }
        }
    }
}

extension PlanRevision {
    func decodedBeforeSnapshot() throws -> PlanSnapshot {
        try PlanSnapshotCoding.decode(beforeSnapshotData).validated()
    }

    func decodedAfterSnapshot() throws -> PlanSnapshot {
        try PlanSnapshotCoding.decode(afterSnapshotData).validated()
    }
}
