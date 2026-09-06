import SwiftUI

struct TaskReorderControls: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: FocusSpacing.small) {
            Button(TaskCopy.moveUp, systemImage: "chevron.up", action: onMoveUp)
                .labelStyle(.iconOnly)
                .disabled(!canMoveUp)
                .accessibilityLabel(TaskCopy.moveUp)
            Button(TaskCopy.moveDown, systemImage: "chevron.down", action: onMoveDown)
                .labelStyle(.iconOnly)
                .disabled(!canMoveDown)
                .accessibilityLabel(TaskCopy.moveDown)
        }
    }
}
