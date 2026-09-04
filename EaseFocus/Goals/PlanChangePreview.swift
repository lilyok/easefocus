import SwiftUI

struct PlanSnapshotComparisonView: View {
    var before: PlanSnapshot
    var after: PlanSnapshot
    var summary: String?
    var changedRowIdentifier: String = "refinePlanChangedTask"
    var protectedRowIdentifier: String = "refinePlanProtectedTask"

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.large) {
            if let summary, !summary.isEmpty {
                previewSection(title: PlanRefinementCopy.summarySection) {
                    Text(summary)
                        .font(FocusTypography.body)
                        .foregroundStyle(Color.focusPrimary)
                }
            }

            previewSection(title: PlanRefinementCopy.beforeSection) {
                ForEach(PlanRefinementPresentation.beforeTasks(before), id: \.id) { task in
                    taskRow(task: task, kind: nil)
                }
            }

            previewSection(title: PlanRefinementCopy.afterSection) {
                ForEach(PlanRefinementPresentation.displayedTasks(before: before, after: after)) { row in
                    taskRow(task: row.after, kind: row.kind, before: row.before)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func previewSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            Text(title)
                .font(FocusTypography.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func taskRow(
        task: TaskSnapshot,
        kind: PlanRefinementChangeKind?,
        before: TaskSnapshot? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: FocusSpacing.small) {
                Text(task.title)
                    .font(FocusTypography.body)
                    .foregroundStyle(Color.focusPrimary)
                    .strikethrough(task.status == .archived)
                if let kind, let badge = PlanRefinementCopy.badge(for: kind) {
                    Text(badge)
                        .font(FocusTypography.footnote.weight(.semibold))
                        .foregroundStyle(Color.focusAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.focusAccent.opacity(0.12), in: Capsule())
                        .fixedSize()
                }
                if let status = PlanRefinementCopy.statusLabel(for: task.status) {
                    Text(status)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if kind == .updated, let before {
                let diff = PlanRefinementPresentation.updateDiff(before: before, after: task)
                if let previousTitle = diff.previousTitle {
                    Text(PlanRefinementCopy.wasTitle(previousTitle))
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
                if let details = diff.details {
                    Text(PlanRefinementCopy.detailsLine(details))
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
                if let previousDetails = diff.previousDetails {
                    Text(PlanRefinementCopy.wasDetails(previousDetails))
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Text(PlanRefinementCopy.estimatedSessions(task.estimatedPomodoros))
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
            if kind == .updated, let before {
                let diff = PlanRefinementPresentation.updateDiff(before: before, after: task)
                if let previousEstimatedPomodoros = diff.previousEstimatedPomodoros {
                    Text(PlanRefinementCopy.wasEstimatedSessions(previousEstimatedPomodoros))
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
                if let searchQuery = diff.searchQuery {
                    Text(PlanRefinementCopy.searchLine(searchQuery))
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
                if let previousSearchQuery = diff.previousSearchQuery {
                    Text(PlanRefinementCopy.wasSearch(previousSearchQuery))
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier(rowIdentifier(kind: kind))
    }

    private func rowIdentifier(kind: PlanRefinementChangeKind?) -> String {
        switch kind {
        case .added, .updated, .archived, .reordered:
            return changedRowIdentifier
        case .protected, .unchanged, nil:
            return protectedRowIdentifier
        }
    }
}
