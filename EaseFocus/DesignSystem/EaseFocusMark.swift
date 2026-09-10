import SwiftUI

/// In-app silhouette matching the App Icon: thick sun / timer dial.
struct EaseFocusMark: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            EaseFocusMarkTicksShape()
                .stroke(
                    Color.focusPrimary,
                    style: StrokeStyle(lineWidth: size * 0.055, lineCap: .round)
                )
            EaseFocusMarkRingShape()
                .stroke(
                    Color.focusPrimary,
                    style: StrokeStyle(lineWidth: size * 0.078, lineCap: .round)
                )
            EaseFocusMarkArcShape()
                .stroke(
                    Color.focusAccent,
                    style: StrokeStyle(lineWidth: size * 0.078, lineCap: .round)
                )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct EaseFocusMarkRingShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.width * 0.22
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        return path
    }
}

struct EaseFocusMarkTicksShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let tickInner = rect.width * 0.295
        let tickOuter = rect.width * 0.37
        var path = Path()
        for index in 0..<12 {
            // SwiftUI angles: 0 = east, y grows down — put a tick at 12 o'clock.
            let degrees = -90.0 + Double(index) * 30.0
            let radians = degrees * .pi / 180
            let dx = CGFloat(cos(radians))
            let dy = CGFloat(sin(radians))
            path.move(to: CGPoint(x: center.x + dx * tickInner, y: center.y + dy * tickInner))
            path.addLine(to: CGPoint(x: center.x + dx * tickOuter, y: center.y + dy * tickOuter))
        }
        return path
    }
}

struct EaseFocusMarkArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width * 0.295
        var path = Path()
        // Match App Icon: ~1 o'clock to ~7:30, clockwise in screen space.
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-60),
            endAngle: .degrees(135),
            clockwise: false
        )
        return path
    }
}

#Preview {
    EaseFocusMark(size: 96)
        .padding()
        .background(Color.focusBackground)
}
