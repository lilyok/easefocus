import SwiftUI

struct TimerPhaseControlButton: View {
    let action: CompactTimerAction
    var usesCompactTitle: Bool
    let perform: () -> Void

    var body: some View {
        Group {
            if action == .cancel {
                Button(role: .destructive, action: perform) {
                    label
                }
            } else if usesCompactTitle {
                Button(action: perform) {
                    label
                }
            } else {
                Button(action: perform) {
                    label
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityIdentifier(action.identifier)
    }

    private var label: some View {
        Text(usesCompactTitle ? action.compactTitle : action.title)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                minWidth: FocusSpacing.minimumTapTarget,
                minHeight: FocusSpacing.minimumTapTarget
            )
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
