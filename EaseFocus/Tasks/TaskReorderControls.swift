import SwiftUI

struct TaskReorderControls: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: FocusSpacing.small) {
            Button("Move task up", systemImage: "chevron.up", action: onMoveUp)
                .labelStyle(.iconOnly)
                .disabled(!canMoveUp)
                .accessibilityLabel("Move task up")
            Button("Move task down", systemImage: "chevron.down", action: onMoveDown)
                .labelStyle(.iconOnly)
                .disabled(!canMoveDown)
                .accessibilityLabel("Move task down")
        }
    }
}
