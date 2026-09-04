import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class PlanHistoryCoordinator {
    private(set) var isUndoConfirmPresented = false
    var isStartOverConfirmPresented = false
    private(set) var actionError: String?
    private(set) var saveErrorMessage: String?
    var isSaveAlertPresented = false
    private(set) var didApply = false

    private var pendingSaveRetry: (() -> Void)?

    func undoAvailability(plan: GoalPlan, isSessionRunningOnPlan: Bool) -> PlanHistoryUndoAvailability {
        guard let last = plan.orderedRevisions.last else {
            return .noRevision
        }
        let current: PlanSnapshot
        let lastAfter: PlanSnapshot
        do {
            current = try PlanSnapshot.capturing(plan).validated()
            lastAfter = try last.decodedAfterSnapshot()
        } catch {
            return .malformed
        }
        return PlanHistoryPresentation.undoAvailability(
            current: current,
            lastAfter: lastAfter,
            isSessionRunningOnPlan: isSessionRunningOnPlan
        )
    }

    func canStartOver(isSessionRunningOnPlan: Bool) -> Bool {
        PlanHistoryPresentation.canStartOver(isSessionRunningOnPlan: isSessionRunningOnPlan)
    }

    func requestUndo(plan: GoalPlan, isSessionRunningOnPlan: Bool) {
        actionError = PlanHistoryCopy.message(for: undoAvailability(plan: plan, isSessionRunningOnPlan: isSessionRunningOnPlan))
        guard undoAvailability(plan: plan, isSessionRunningOnPlan: isSessionRunningOnPlan) == .available else {
            isUndoConfirmPresented = false
            return
        }
        isUndoConfirmPresented = true
    }

    func discardUndo() {
        isUndoConfirmPresented = false
    }

    func requestStartOver(isSessionRunningOnPlan: Bool) {
        if !canStartOver(isSessionRunningOnPlan: isSessionRunningOnPlan) {
            actionError = PlanHistoryCopy.sessionRunning
            isStartOverConfirmPresented = false
            return
        }
        actionError = nil
        isStartOverConfirmPresented = true
    }

    func confirmUndo(
        plan: GoalPlan,
        context: ModelContext,
        isSessionRunningOnPlan: Bool,
        now: Date = .now,
        save: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        guard isUndoConfirmPresented || pendingSaveRetry != nil else {
            return
        }
        applyResult(
            PlanHistoryApplying.undoLast(
                on: plan,
                in: context,
                isSessionRunningOnPlan: isSessionRunningOnPlan,
                now: now,
                save: save
            ),
            retry: { [weak self] in
                self?.confirmUndo(
                    plan: plan,
                    context: context,
                    isSessionRunningOnPlan: isSessionRunningOnPlan,
                    now: now,
                    save: save
                )
            }
        )
    }

    func confirmStartOver(
        plan: GoalPlan,
        context: ModelContext,
        isSessionRunningOnPlan: Bool,
        now: Date = .now,
        save: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        guard isStartOverConfirmPresented || pendingSaveRetry != nil else {
            return
        }
        isStartOverConfirmPresented = false
        applyResult(
            PlanHistoryApplying.startOver(
                on: plan,
                in: context,
                isSessionRunningOnPlan: isSessionRunningOnPlan,
                now: now,
                save: save
            ),
            retry: { [weak self] in
                self?.confirmStartOver(
                    plan: plan,
                    context: context,
                    isSessionRunningOnPlan: isSessionRunningOnPlan,
                    now: now,
                    save: save
                )
            }
        )
    }

    func retrySave() {
        pendingSaveRetry?()
    }

    func discardFailedSave() {
        isSaveAlertPresented = false
        saveErrorMessage = nil
        pendingSaveRetry = nil
    }

    private func applyResult(
        _ result: PlanHistoryApplyResult,
        retry: @escaping () -> Void
    ) {
        switch result {
        case .applied:
            didApply = true
            isUndoConfirmPresented = false
            isStartOverConfirmPresented = false
            actionError = nil
            saveErrorMessage = nil
            isSaveAlertPresented = false
            pendingSaveRetry = nil
        case .stale:
            isUndoConfirmPresented = false
            actionError = PlanHistoryCopy.staleUndo
        case .noRevision:
            isUndoConfirmPresented = false
            actionError = PlanHistoryCopy.noRevision
        case .sessionRunning:
            isUndoConfirmPresented = false
            isStartOverConfirmPresented = false
            actionError = PlanHistoryCopy.sessionRunning
        case .malformed:
            isUndoConfirmPresented = false
            actionError = PlanHistoryCopy.malformed
        case .saveFailed:
            isUndoConfirmPresented = false
            saveErrorMessage = PersistenceSaveCopy.message
            isSaveAlertPresented = true
            pendingSaveRetry = retry
        }
    }
}

@MainActor
enum PlanHistorySession {
    static func isRunning(on plan: GoalPlan, timer: FocusTimerController) -> Bool {
        PlanHistoryPresentation.isSessionRunning(
            planTaskIDs: Set(plan.tasks.map(\.id)),
            hasActiveTask: plan.tasks.contains { $0.status == .active },
            timerTaskID: timer.engine.taskID,
            timerPhase: timer.engine.phase
        )
    }
}
