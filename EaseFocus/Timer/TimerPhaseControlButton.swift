import SwiftUI

struct TimerPhaseControlButton: View {
    let action: CompactTimerAction
    var usesCompactTitle: Bool
    let perform: () -> Void

    var body: some View {
        Button(role: action == .cancel ? .destructive : nil, action: perform) {
            Text(usesCompactTitle ? action.compactTitle : action.title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    minWidth: FocusSpacing.minimumTapTarget,
                    minHeight: FocusSpacing.minimumTapTarget
                )
        }
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
