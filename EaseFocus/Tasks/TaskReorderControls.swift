import SwiftUI

struct TaskReorderControls: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: FocusSpacing.small) {
            reorderButton(
                systemImage: "chevron.up",
                enabled: canMoveUp,
                label: TaskCopy.moveUp,
                action: onMoveUp
            )
            reorderButton(
                systemImage: "chevron.down",
                enabled: canMoveDown,
                label: TaskCopy.moveDown,
                action: onMoveDown
            )
        }
    }

    private func reorderButton(
        systemImage: String,
        enabled: Bool,
        label: LocalizedCopy,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: FocusSpacing.minimumTapTarget, height: FocusSpacing.minimumTapTarget)
                .background(FocusChrome.gradient(for: .accent, enabled: enabled), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(FocusCapsuleButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
