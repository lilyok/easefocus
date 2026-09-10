import SwiftUI

extension View {
    /// Prominent next-step control. Relies on the app-wide FocusAccent tint.
    func focusPrimaryActionStyle() -> some View {
        buttonStyle(.borderedProminent)
            .frame(
                minWidth: FocusSpacing.minimumTapTarget,
                minHeight: FocusSpacing.minimumTapTarget
            )
    }
}
