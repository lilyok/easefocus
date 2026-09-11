import SwiftUI

extension View {
    /// Prominent in-content next-step control with a 44pt minimum tap target.
    /// Relies on the app-wide FocusAccent tint. Prefer `focusPrimaryToolbarActionStyle()`
    /// for `ToolbarItem` confirmations so navigation bars are not forced to 44pt frames.
    func focusPrimaryActionStyle() -> some View {
        buttonStyle(.borderedProminent)
            .frame(
                minWidth: FocusSpacing.minimumTapTarget,
                minHeight: FocusSpacing.minimumTapTarget
            )
    }

    /// Prominent toolbar confirmation styling without an extra minimum-size frame.
    func focusPrimaryToolbarActionStyle() -> some View {
        buttonStyle(.borderedProminent)
    }
}
