import SwiftUI

struct TaskRowView: View {
    let task: PlanTask
    var onMarkCompleted: (() -> Void)? = nil
    var onStart: (() -> Void)? = nil
    var isStartEnabled: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: FocusSpacing.medium) {
            completionControl
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(FocusTypography.body)
                    .strikethrough(task.status == .completed)
                Text(sessionCountCopy)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let onStart, task.status != .completed {
                Button(TaskCopy.start, action: onStart)
                    .disabled(!isStartEnabled)
                    .frame(
                        minWidth: FocusSpacing.minimumTapTarget,
                        minHeight: FocusSpacing.minimumTapTarget
                    )
                    .accessibilityLabel(TaskCopy.startFocus)
            }
        }
        .frame(minHeight: FocusSpacing.minimumTapTarget)
    }

    private var sessionCountCopy: LocalizedCopy {
        if task.brokenSessionCount > 0 {
            return TaskCopy.sessionCountWithBroken(
                completed: task.completedSessionCount,
                estimated: task.estimatedPomodoros,
                broken: task.brokenSessionCount
            )
        }
        return TaskCopy.sessionCount(
            completed: task.completedSessionCount,
            estimated: task.estimatedPomodoros
        )
    }

    @ViewBuilder
    private var completionControl: some View {
        let icon = Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(task.status == .completed ? Color.focusSuccess : Color.focusPrimary)
            .frame(width: FocusSpacing.minimumTapTarget, height: FocusSpacing.minimumTapTarget)

        if let onMarkCompleted {
            Button(action: onMarkCompleted) {
                icon
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                task.status == .completed ? TaskCopy.markNotCompleted : TaskCopy.markCompleted
            )
            .accessibilityIdentifier("markTaskCompleted")
        } else {
            icon
                .accessibilityLabel(
                    task.status == .completed ? TaskCopy.completed : TaskCopy.notCompleted
                )
        }
    }
}

extension View {
    func taskRowActions(
        canStart: Bool,
        onStart: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canStart {
                Button(TaskCopy.startFocus, action: onStart)
                    .tint(Color.focusAccent)
            }
            Button(TaskCopy.remove, role: .destructive, action: onRemove)
        }
        .contextMenu {
            if canStart {
                Button(TaskCopy.startFocus, action: onStart)
            }
            Button(TaskCopy.remove, role: .destructive, action: onRemove)
        }
    }
}
