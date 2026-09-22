import SwiftUI

struct SwipeRevealAction: Identifiable {
    var id: String
    var title: LocalizedCopy
    var kind: FocusChrome.Kind
    var handler: () -> Void
}

struct SwipeRevealModifier: ViewModifier {
    var actions: [SwipeRevealAction]
    @State private var offset: CGFloat = 0

    private let actionWidth: CGFloat = 96

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            revealControls
            content
                .offset(x: contentOffset)
                .simultaneousGesture(drag)
        }
        .clipped()
        .contentShape(Rectangle())
        .onChange(of: actions.map(\.id).joined(separator: ",")) { _, _ in
            offset = 0
        }
    }

    private var revealWidth: CGFloat {
        actionWidth * CGFloat(max(actions.count, 1))
    }

    private var contentOffset: CGFloat {
        min(0, max(-revealWidth, offset))
    }

    private var revealControls: some View {
        HStack(spacing: 0) {
            ForEach(actions) { action in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = 0
                    }
                    action.handler()
                } label: {
                    Text(action.title)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(width: actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(FocusChrome.gradient(for: action.kind))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.title)
            }
        }
        .opacity(contentOffset < -8 ? 1 : 0)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) else {
                    return
                }
                offset = min(0, max(-revealWidth, horizontal))
            }
            .onEnded { value in
                let shouldReveal = value.translation.width < -(revealWidth / 3)
                withAnimation(.easeOut(duration: 0.2)) {
                    offset = shouldReveal ? -revealWidth : 0
                }
            }
    }
}

extension View {
    func swipeReveal(actions: [SwipeRevealAction]) -> some View {
        modifier(SwipeRevealModifier(actions: actions))
    }

    func swipeToRemove(action: @escaping () -> Void) -> some View {
        swipeReveal(
            actions: [
                SwipeRevealAction(
                    id: "remove",
                    title: TaskCopy.remove,
                    kind: .destructive,
                    handler: action
                ),
            ]
        )
    }
}
