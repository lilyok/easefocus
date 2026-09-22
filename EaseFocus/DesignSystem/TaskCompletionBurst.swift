import SwiftUI

struct TaskCompletionBurst: View {
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Capsule()
                    .fill(FocusChrome.gradient(for: index.isMultiple(of: 2) ? .accent : .destructive))
                    .frame(width: 8, height: isExpanded ? 22 : 8)
                    .offset(y: isExpanded ? -46 : 0)
                    .rotationEffect(.degrees(Double(index) * 36))
                    .opacity(isExpanded ? 0 : 1)
            }
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(Color.focusSuccess)
                .scaleEffect(isExpanded ? 1 : 0.4)
                .opacity(isExpanded ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.focusBackground.opacity(isExpanded ? 0.28 : 0))
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                isExpanded = true
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
