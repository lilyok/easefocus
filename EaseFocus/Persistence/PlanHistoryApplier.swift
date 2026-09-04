import Foundation
import SwiftData

nonisolated enum PlanHistoryApplierError: Equatable, Error {
    case stale
    case noRevision
    case sessionRunning
    case malformed
    case saveFailed
}

enum PlanHistoryApplier {
    @MainActor
    static func undoLast(
        on plan: GoalPlan,
        in context: ModelContext,
        isSessionRunningOnPlan: Bool,
        now: Date = .now,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        guard !isSessionRunningOnPlan else {
            throw PlanHistoryApplierError.sessionRunning
        }
        guard let revision = plan.orderedRevisions.last else {
            throw PlanHistoryApplierError.noRevision
        }

        let current: PlanSnapshot
        let lastAfter: PlanSnapshot
        let lastBefore: PlanSnapshot
        do {
            current = try PlanSnapshot.capturing(plan).validated()
            lastAfter = try revision.decodedAfterSnapshot()
            lastBefore = try revision.decodedBeforeSnapshot()
        } catch {
            throw PlanHistoryApplierError.malformed
        }

        guard current == lastAfter else {
            throw PlanHistoryApplierError.stale
        }

        let restored: PlanSnapshot
        do {
            restored = try finalizedRestoreSnapshot(current: current, target: lastBefore, plan: plan)
        } catch {
            throw PlanHistoryApplierError.malformed
        }

        try apply(
            before: current,
            after: restored,
            to: plan,
            in: context,
            reason: PlanHistoryCopy.undoReason,
            changeSummary: PlanHistoryCopy.undoSummary(restoringReason: revision.reason),
            now: now,
            save: save
        )
    }

    @MainActor
    static func startOver(
        on plan: GoalPlan,
        in context: ModelContext,
        isSessionRunningOnPlan: Bool,
        now: Date = .now,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        guard !isSessionRunningOnPlan else {
            throw PlanHistoryApplierError.sessionRunning
        }

        let current: PlanSnapshot
        let after: PlanSnapshot
        do {
            current = try PlanSnapshot.capturing(plan).validated()
            after = try PlanHistoryPresentation.startOverSnapshot(current: current)
        } catch {
            throw PlanHistoryApplierError.malformed
        }

        try apply(
            before: current,
            after: after,
            to: plan,
            in: context,
            reason: PlanHistoryCopy.startOverReason,
            changeSummary: PlanHistoryCopy.startOverSummary,
            now: now,
            save: save
        )
    }

    @MainActor
    private static func finalizedRestoreSnapshot(
        current: PlanSnapshot,
        target: PlanSnapshot,
        plan: GoalPlan
    ) throws -> PlanSnapshot {
        var restored = try PlanHistoryPresentation.restoredSnapshot(current: current, target: target)
        let restoredIDs = Set(restored.tasks.map(\.id))
        var extras: [TaskSnapshot] = []
        for task in plan.orderedTasks where !restoredIDs.contains(task.id) {
            if task.status == .completed || task.status == .active {
                extras.append(TaskSnapshot.capturing(task))
            } else if !task.sessions.isEmpty {
                var snapshot = TaskSnapshot.capturing(task)
                snapshot.status = .archived
                extras.append(snapshot)
            }
        }
        guard !extras.isEmpty else {
            return restored
        }
        restored.tasks.append(contentsOf: extras)
        for index in restored.tasks.indices {
            restored.tasks[index].position = index
        }
        return try restored.validated()
    }

    @MainActor
    private static func apply(
        before: PlanSnapshot,
        after: PlanSnapshot,
        to plan: GoalPlan,
        in context: ModelContext,
        reason: String,
        changeSummary: String,
        now: Date,
        save: (ModelContext) throws -> Void
    ) throws {
        do {
            try PlanRevisionFactory.preserveCompletedWork(from: before, to: after)
            _ = try after.validated()
        } catch {
            throw PlanHistoryApplierError.malformed
        }

        let originalTaskIDs = Set(plan.tasks.map(\.id))
        let originalRevisionIDs = Set(plan.revisions.map(\.id))
        let originalUpdatedAt = plan.updatedAt
        let originalTaskTimestamps = Dictionary(uniqueKeysWithValues: plan.tasks.map { ($0.id, $0.updatedAt) })
        let afterIDs = Set(after.tasks.map(\.id))
        let protectedIDs = Set(
            plan.tasks.filter { $0.status == .completed || $0.status == .active }.map(\.id)
        )
        guard protectedIDs.isSubset(of: afterIDs) else {
            throw PlanHistoryApplierError.malformed
        }

        let beforeByID = Dictionary(uniqueKeysWithValues: before.tasks.map { ($0.id, $0) })
        let existingByID = Dictionary(uniqueKeysWithValues: plan.tasks.map { ($0.id, $0) })

        do {
            let revision = try PlanRevisionFactory.make(
                for: plan,
                reason: reason,
                source: .user,
                changeSummary: changeSummary,
                before: before,
                after: after,
                now: now
            )
            applyTaskMutations(
                after: after,
                plan: plan,
                context: context,
                beforeByID: beforeByID,
                existingByID: existingByID,
                now: now
            )
            plan.title = after.title
            plan.details = after.details
            plan.updatedAt = now
            context.insert(revision)
            try save(context)
        } catch {
            discardFailedApplication(
                plan: plan,
                before: before,
                context: context,
                originalTaskIDs: originalTaskIDs,
                originalRevisionIDs: originalRevisionIDs,
                originalUpdatedAt: originalUpdatedAt,
                originalTaskTimestamps: originalTaskTimestamps
            )
            if error is PlanRevisionFactoryError {
                throw PlanHistoryApplierError.malformed
            }
            throw PlanHistoryApplierError.saveFailed
        }
    }

    @MainActor
    private static func applyTaskMutations(
        after: PlanSnapshot,
        plan: GoalPlan,
        context: ModelContext,
        beforeByID: [UUID: TaskSnapshot],
        existingByID: [UUID: PlanTask],
        now: Date
    ) {
        let afterIDs = Set(after.tasks.map(\.id))
        for afterTask in after.tasks {
            if let existing = existingByID[afterTask.id] {
                let originalStatus = beforeByID[existing.id]?.status ?? existing.status
                if originalStatus == .completed || originalStatus == .active {
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

        let idsToDelete = Array(plan.tasks).compactMap { task -> UUID? in
            guard !afterIDs.contains(task.id) else { return nil }
            if task.status == .completed || task.status == .active {
                return nil
            }
            if !task.sessions.isEmpty {
                task.status = .archived
                task.updatedAt = now
                return nil
            }
            return task.id
        }
        if !idsToDelete.isEmpty {
            let deleteSet = Set(idsToDelete)
            for task in Array(plan.tasks) where deleteSet.contains(task.id) {
                task.plan = nil
                context.delete(task)
            }
            plan.tasks.removeAll { deleteSet.contains($0.id) }
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
        for task in Array(plan.tasks) where !originalTaskIDs.contains(task.id) {
            task.plan = nil
            context.delete(task)
        }
        plan.tasks.removeAll { !originalTaskIDs.contains($0.id) }

        for revision in Array(plan.revisions) where !originalRevisionIDs.contains(revision.id) {
            revision.plan = nil
            context.delete(revision)
        }
        plan.revisions.removeAll { !originalRevisionIDs.contains($0.id) }

        let remainingTasks = Dictionary(uniqueKeysWithValues: plan.tasks.map { ($0.id, $0) })
        for snapshot in before.tasks {
            if let task = remainingTasks[snapshot.id] {
                task.title = snapshot.title
                task.details = snapshot.details
                task.position = snapshot.position
                task.estimatedPomodoros = snapshot.estimatedPomodoros
                task.status = snapshot.status
                task.searchQuery = snapshot.searchQuery
                if let updatedAt = originalTaskTimestamps[snapshot.id] {
                    task.updatedAt = updatedAt
                }
            } else {
                let restored = PlanTask(
                    id: snapshot.id,
                    title: snapshot.title,
                    details: snapshot.details,
                    position: snapshot.position,
                    estimatedPomodoros: snapshot.estimatedPomodoros,
                    status: snapshot.status,
                    searchQuery: snapshot.searchQuery
                )
                restored.plan = plan
                plan.tasks.append(restored)
                context.insert(restored)
            }
        }
        plan.title = before.title
        plan.details = before.details
        plan.updatedAt = originalUpdatedAt
    }
}

nonisolated enum PlanHistoryApplyResult: Equatable, Sendable {
    case applied
    case stale
    case noRevision
    case sessionRunning
    case malformed
    case saveFailed
}

enum PlanHistoryApplying {
    @MainActor
    static func undoLast(
        on plan: GoalPlan,
        in context: ModelContext,
        isSessionRunningOnPlan: Bool,
        now: Date = .now,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) -> PlanHistoryApplyResult {
        do {
            try PlanHistoryApplier.undoLast(
                on: plan,
                in: context,
                isSessionRunningOnPlan: isSessionRunningOnPlan,
                now: now,
                save: save
            )
            return .applied
        } catch let error as PlanHistoryApplierError {
            return result(for: error)
        } catch {
            return .malformed
        }
    }

    @MainActor
    static func startOver(
        on plan: GoalPlan,
        in context: ModelContext,
        isSessionRunningOnPlan: Bool,
        now: Date = .now,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) -> PlanHistoryApplyResult {
        do {
            try PlanHistoryApplier.startOver(
                on: plan,
                in: context,
                isSessionRunningOnPlan: isSessionRunningOnPlan,
                now: now,
                save: save
            )
            return .applied
        } catch let error as PlanHistoryApplierError {
            return result(for: error)
        } catch {
            return .malformed
        }
    }

    private static func result(for error: PlanHistoryApplierError) -> PlanHistoryApplyResult {
        switch error {
        case .stale:
            return .stale
        case .noRevision:
            return .noRevision
        case .sessionRunning:
            return .sessionRunning
        case .malformed:
            return .malformed
        case .saveFailed:
            return .saveFailed
        }
    }
}
