import SwiftUI

/// In-app silhouette matching the App Icon: open focus ring + completion check.
struct EaseFocusMark: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            EaseFocusMarkRingShape()
                .stroke(
                    Color.focusPrimary,
                    style: StrokeStyle(lineWidth: size * 0.10, lineCap: .round)
                )
            EaseFocusMarkCheckShape()
                .stroke(
                    Color.focusAccent,
                    style: StrokeStyle(lineWidth: size * 0.095, lineCap: .round, lineJoin: .round)
                )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct EaseFocusMarkRingShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.17
        let ringRect = rect.insetBy(dx: inset, dy: inset)
        var path = Path()
        // SwiftUI y grows downward; keep the gap at the top-right like the App Icon.
        path.addArc(
            center: CGPoint(x: ringRect.midX, y: ringRect.midY),
            radius: ringRect.width / 2,
            startAngle: .degrees(-40),
            endAngle: .degrees(35),
            clockwise: true
        )
        return path
    }
}

struct EaseFocusMarkCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        let start = CGPoint(x: rect.minX + w * 0.62, y: rect.minY + h * 0.30)
        let mid = CGPoint(x: rect.minX + w * 0.72, y: rect.minY + h * 0.42)
        let end = CGPoint(x: rect.minX + w * 0.88, y: rect.minY + h * 0.22)
        path.move(to: start)
        path.addLine(to: mid)
        path.addLine(to: end)
        return path
    }
}

#Preview {
    EaseFocusMark(size: 96)
        .padding()
        .background(Color.focusBackground)
}
