import SwiftUI

struct TaskRowView: View {
    let task: PlanTask
    var onStart: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: FocusSpacing.medium) {
            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.status == .completed ? Color.focusSuccess : Color.focusPrimary)
                .frame(width: FocusSpacing.minimumTapTarget, height: FocusSpacing.minimumTapTarget)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(FocusTypography.body)
                    .strikethrough(task.status == .completed)
                Text("\(task.completedSessionCount)/\(task.estimatedPomodoros) sessions")
                    .font(FocusTypography.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let onStart, task.status != .completed {
                Button("Start", action: onStart)
            }
        }
        .frame(minHeight: FocusSpacing.minimumTapTarget)
    }
}
