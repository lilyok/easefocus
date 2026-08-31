import Foundation

nonisolated enum PlanRevisionFactoryError: Equatable, Error {
    case emptyReason
    case malformedSnapshot
    case duplicateTaskIDs
    case invalidOrdering
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
}

extension PlanRevision {
    func decodedBeforeSnapshot() throws -> PlanSnapshot {
        try PlanSnapshotCoding.decode(beforeSnapshotData).validated()
    }

    func decodedAfterSnapshot() throws -> PlanSnapshot {
        try PlanSnapshotCoding.decode(afterSnapshotData).validated()
    }
}
