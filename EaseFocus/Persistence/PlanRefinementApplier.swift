import Foundation
import SwiftData

nonisolated enum PlanRefinementApplierError: Equatable, Error {
    case stalePreview
    case malformedPreview
    case saveFailed
}

enum PlanRefinementApplier {
    @MainActor
    static func apply(
        _ preview: PlanRefinementPreview,
        to plan: GoalPlan,
        in context: ModelContext,
        now: Date = .now,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        let current: PlanSnapshot
        let validatedAfter: PlanSnapshot
        do {
            current = try PlanSnapshot.capturing(plan).validated()
            validatedAfter = try preview.after.validated()
            _ = try preview.before.validated()
        } catch {
            throw PlanRefinementApplierError.malformedPreview
        }

        guard current == preview.before else {
            throw PlanRefinementApplierError.stalePreview
        }

        do {
            try PlanRevisionFactory.preserveCompletedWork(from: preview.before, to: validatedAfter)
            try PlanRefinementValidator.preserveProtectedWork(from: preview.before, to: validatedAfter)
        } catch {
            throw PlanRefinementApplierError.malformedPreview
        }

        let originalTaskIDs = Set(plan.tasks.map(\.id))
        let originalRevisionIDs = Set(plan.revisions.map(\.id))
        let originalUpdatedAt = plan.updatedAt
        let originalTaskTimestamps = Dictionary(uniqueKeysWithValues: plan.tasks.map { ($0.id, $0.updatedAt) })
        let afterIDs = Set(validatedAfter.tasks.map(\.id))
        guard originalTaskIDs.isSubset(of: afterIDs) else {
            throw PlanRefinementApplierError.malformedPreview
        }

        let beforeByID = Dictionary(uniqueKeysWithValues: preview.before.tasks.map { ($0.id, $0) })
        let existingByID = Dictionary(uniqueKeysWithValues: plan.tasks.map { ($0.id, $0) })

        do {
            let revision = try PlanRevisionFactory.make(
                for: plan,
                reason: preview.request,
                source: .model,
                changeSummary: preview.changeSummary,
                before: preview.before,
                after: validatedAfter,
                now: now
            )
            applyTaskMutations(
                validatedAfter: validatedAfter,
                plan: plan,
                context: context,
                beforeByID: beforeByID,
                existingByID: existingByID,
                now: now
            )
            plan.updatedAt = now
            context.insert(revision)
            try save(context)
        } catch {
            discardFailedApplication(
                plan: plan,
                before: preview.before,
                context: context,
                originalTaskIDs: originalTaskIDs,
                originalRevisionIDs: originalRevisionIDs,
                originalUpdatedAt: originalUpdatedAt,
                originalTaskTimestamps: originalTaskTimestamps
            )
            if error is PlanRevisionFactoryError {
                throw PlanRefinementApplierError.malformedPreview
            }
            throw PlanRefinementApplierError.saveFailed
        }
    }

    @MainActor
    private static func applyTaskMutations(
        validatedAfter: PlanSnapshot,
        plan: GoalPlan,
        context: ModelContext,
        beforeByID: [UUID: TaskSnapshot],
        existingByID: [UUID: PlanTask],
        now: Date
    ) {
        for afterTask in validatedAfter.tasks {
            if let existing = existingByID[afterTask.id] {
                let originalStatus = beforeByID[existing.id]?.status
                if originalStatus == .completed || originalStatus == .active || originalStatus == .archived {
                    if existing.position != afterTask.position {
                        existing.position = afterTask.position
                    }
                    continue
                }
                existing.title = afterTask.title
                existing.details = afterTask.details
                existing.position = afterTask.position
                existing.estimatedPomodoros = afterTask.estimatedPomodoros
                existing.status = afterTask.status
                existing.searchQuery = afterTask.searchQuery
                existing.updatedAt = now
            } else {
                let created = PlanTask(
                    id: afterTask.id,
                    title: afterTask.title,
                    details: afterTask.details,
                    position: afterTask.position,
                    estimatedPomodoros: afterTask.estimatedPomodoros,
                    status: afterTask.status,
                    createdAt: now,
                    updatedAt: now,
                    searchQuery: afterTask.searchQuery
                )
                created.plan = plan
                if !plan.tasks.contains(where: { $0.id == created.id }) {
                    plan.tasks.append(created)
                }
                context.insert(created)
            }
        }
    }

    @MainActor
    private static func discardFailedApplication(
        plan: GoalPlan,
        before: PlanSnapshot,
        context: ModelContext,
        originalTaskIDs: Set<UUID>,
        originalRevisionIDs: Set<UUID>,
        originalUpdatedAt: Date,
        originalTaskTimestamps: [UUID: Date]
    ) {
        for task in plan.tasks where !originalTaskIDs.contains(task.id) {
            task.plan = nil
            context.delete(task)
        }
        plan.tasks.removeAll { !originalTaskIDs.contains($0.id) }

        for revision in plan.revisions where !originalRevisionIDs.contains(revision.id) {
            revision.plan = nil
            context.delete(revision)
        }
        plan.revisions.removeAll { !originalRevisionIDs.contains($0.id) }

        let remainingTasks = Dictionary(uniqueKeysWithValues: plan.tasks.map { ($0.id, $0) })
        for snapshot in before.tasks {
            guard let task = remainingTasks[snapshot.id] else {
                continue
            }
            task.title = snapshot.title
            task.details = snapshot.details
            task.position = snapshot.position
            task.estimatedPomodoros = snapshot.estimatedPomodoros
            task.status = snapshot.status
            task.searchQuery = snapshot.searchQuery
            if let updatedAt = originalTaskTimestamps[snapshot.id] {
                task.updatedAt = updatedAt
            }
        }
        plan.updatedAt = originalUpdatedAt
    }
}
