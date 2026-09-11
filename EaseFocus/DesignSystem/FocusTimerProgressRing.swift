import SwiftUI

/// Thin FocusAccent progress arc around timer remaining time. Decorative only.
struct FocusTimerProgressRing: View {
    var progress: CGFloat
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.focusPrimary.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    Color.focusAccent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    FocusTimerProgressRing(progress: 0.35)
        .frame(width: 160, height: 160)
        .padding()
        .background(Color.focusBackground)
}
