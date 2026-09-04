import SwiftData
import SwiftUI

struct PlanHistoryView: View {
    @Bindable var plan: GoalPlan
    @State private var coordinator = PlanHistoryCoordinator()
    @Environment(FocusTimerController.self) private var timer

    private var isSessionRunning: Bool {
        PlanHistorySession.isRunning(on: plan, timer: timer)
    }

    private var items: [PlanHistoryItem] {
        PlanHistoryPresentation.displayedRevisions(plan.historyRecords)
    }

    private var undoAvailability: PlanHistoryUndoAvailability {
        coordinator.undoAvailability(plan: plan, isSessionRunningOnPlan: isSessionRunning)
    }

    var body: some View {
        List {
            if let actionError = coordinator.actionError {
                Section {
                    Text(actionError)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(Color.focusError)
                }
            } else if let message = PlanHistoryCopy.message(for: undoAvailability), undoAvailability != .available {
                Section {
                    Text(message)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(items) { item in
                NavigationLink {
                    PlanRevisionDetailView(plan: plan, revisionID: item.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.reason)
                            .font(FocusTypography.body)
                            .foregroundStyle(Color.focusPrimary)
                        Text(item.changeSummary)
                            .font(FocusTypography.footnote)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(item.createdAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                            Text(PlanHistoryCopy.sourceLabel(for: item.source))
                        }
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.focusBackground)
        .navigationTitle(PlanHistoryCopy.historyTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(PlanHistoryCopy.undoAction) {
                    coordinator.requestUndo(plan: plan, isSessionRunningOnPlan: isSessionRunning)
                }
                .disabled(undoAvailability != .available)
                .accessibilityIdentifier(PlanHistoryAccessibilityIdentifier.undo)
            }
        }
        .sheet(isPresented: Binding(
            get: { coordinator.isUndoConfirmPresented },
            set: { if !$0 { coordinator.discardUndo() } }
        )) {
            PlanUndoConfirmationView(plan: plan, coordinator: coordinator)
        }
        .persistenceSaveAlert(
            isPresented: $coordinator.isSaveAlertPresented,
            message: coordinator.saveErrorMessage,
            onRetry: { coordinator.retrySave() },
            onDiscard: { coordinator.discardFailedSave() }
        )
    }
}

struct PlanRevisionDetailView: View {
    @Bindable var plan: GoalPlan
    var revisionID: UUID

    private var revision: PlanRevision? {
        plan.revisions.first { $0.id == revisionID }
    }

    var body: some View {
        Group {
            if let revision,
               let snapshots = PlanHistoryPresentation.decodedSnapshots(
                before: revision.beforeSnapshotData,
                after: revision.afterSnapshotData
               ) {
                ScrollView {
                    PlanSnapshotComparisonView(
                        before: snapshots.before,
                        after: snapshots.after,
                        summary: revision.changeSummary
                    )
                    .padding(FocusSpacing.medium)
                }
            } else {
                ContentUnavailableView {
                    Label(PlanHistoryCopy.unreadableRevision, systemImage: "clock.badge.questionmark")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.focusBackground)
        .navigationTitle(PlanHistoryCopy.revisionTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct PlanUndoConfirmationView: View {
    @Bindable var plan: GoalPlan
    @Bindable var coordinator: PlanHistoryCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusTimerController.self) private var timer

    private var snapshots: (before: PlanSnapshot, after: PlanSnapshot)? {
        guard let last = plan.orderedRevisions.last else {
            return nil
        }
        return PlanHistoryPresentation.decodedSnapshots(
            before: last.beforeSnapshotData,
            after: last.afterSnapshotData
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let snapshots {
                    ScrollView {
                        VStack(alignment: .leading, spacing: FocusSpacing.large) {
                            Text(PlanHistoryCopy.undoConfirmMessage)
                                .font(FocusTypography.footnote)
                                .foregroundStyle(.secondary)
                            PlanSnapshotComparisonView(
                                before: snapshots.after,
                                after: snapshots.before,
                                summary: PlanHistoryCopy.undoSummary(
                                    restoringReason: plan.orderedRevisions.last?.reason ?? ""
                                )
                            )
                        }
                        .padding(FocusSpacing.medium)
                    }
                } else {
                    Text(PlanHistoryCopy.unreadableRevision)
                        .font(FocusTypography.footnote)
                        .padding(FocusSpacing.medium)
                }
            }
            .background(Color.focusBackground)
            .navigationTitle(PlanHistoryCopy.undoConfirmTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PlanHistoryCopy.discardUndo) {
                        coordinator.discardUndo()
                        dismiss()
                    }
                    .accessibilityIdentifier(PlanHistoryAccessibilityIdentifier.discardUndo)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(PlanHistoryCopy.confirmUndo) {
                        coordinator.confirmUndo(
                            plan: plan,
                            context: modelContext,
                            isSessionRunningOnPlan: PlanHistorySession.isRunning(on: plan, timer: timer)
                        )
                    }
                    .disabled(snapshots == nil)
                    .accessibilityIdentifier(PlanHistoryAccessibilityIdentifier.confirmUndo)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560, idealHeight: 640, maxHeight: 780)
        #endif
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }
}

extension GoalPlan {
    var historyRecords: [PlanHistoryRevisionRecord] {
        orderedRevisions.map { revision in
            PlanHistoryRevisionRecord(
                id: revision.id,
                createdAt: revision.createdAt,
                reason: revision.reason,
                changeSummary: revision.changeSummary,
                source: revision.source
            )
        }
    }
}
