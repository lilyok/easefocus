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
                Text(sessionCountLabel)
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let onStart, task.status != .completed {
                Button("Start", action: onStart)
                    .disabled(!isStartEnabled)
            }
        }
        .frame(minHeight: FocusSpacing.minimumTapTarget)
    }

    private var sessionCountLabel: String {
        var label = "\(task.completedSessionCount)/\(task.estimatedPomodoros) sessions"
        if task.brokenSessionCount > 0 {
            label += " · \(task.brokenSessionCount) broken"
        }
        return label
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
            .accessibilityLabel(task.status == .completed ? "Mark as not completed" : "Mark completed")
            .accessibilityIdentifier("markTaskCompleted")
        } else {
            icon
                .accessibilityLabel(task.status == .completed ? "Completed" : "Not completed")
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
                Button("Start focus", action: onStart)
                    .tint(Color.focusAccent)
            }
            Button("Remove", role: .destructive, action: onRemove)
        }
        .contextMenu {
            if canStart {
                Button("Start focus", action: onStart)
            }
            Button("Remove", role: .destructive, action: onRemove)
        }
    }
}
