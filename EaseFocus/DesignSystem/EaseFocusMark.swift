import SwiftUI

/// In-app silhouette matching the App Icon: tomato face + timer ticks.
struct EaseFocusMark: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.89, green: 0.36, blue: 0.29))
                .frame(width: size * 0.68, height: size * 0.68)
            EaseFocusMarkCalyxShape()
                .fill(Color.focusSuccess)
            EaseFocusMarkTicksShape()
                .stroke(
                    Color.focusPrimary,
                    style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round)
                )
            EaseFocusMarkArcShape()
                .stroke(
                    FocusChrome.gradient(for: .accent),
                    style: StrokeStyle(lineWidth: size * 0.078, lineCap: .round)
                )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

nonisolated struct EaseFocusMarkCalyxShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = rect.width * 0.13
        let inner = rect.width * 0.05
        var path = Path()
        for index in 0..<16 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = Double(index) * .pi / 8 - .pi / 2
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

nonisolated struct EaseFocusMarkTicksShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let tickInner = rect.width * 0.40
        let tickOuter = rect.width * 0.46
        var path = Path()
        for index in 0..<12 {
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

nonisolated struct EaseFocusMarkArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width * 0.40
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-50),
            endAngle: .degrees(140),
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
