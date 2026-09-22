import SwiftUI

struct TimerPhaseControlButton: View {
    let action: CompactTimerAction
    var usesCompactTitle: Bool
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            Text(usesCompactTitle ? action.compactTitle : action.title)
                .lineLimit(2)
                .focusCapsuleFill(
                    action == .cancel ? Color.focusError : Color.focusAccent,
                    enabled: true
                )
        }
        .buttonStyle(FocusCapsuleButtonStyle())
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityIdentifier(action.identifier)
    }
}

extension FocusTimerController {
    func perform(_ action: CompactTimerAction) {
        switch action {
        case .pause:
            pause()
        case .resume:
            resume()
        case .cancel:
            cancel()
        case .startBreak:
            startBreak()
        case .skipBreak:
            skipBreak()
        }
    }
}
