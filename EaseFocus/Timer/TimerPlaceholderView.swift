import SwiftUI

struct TimerPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Timer", systemImage: "timer")
        } description: {
            Text("The focus timer state machine lands in Phase 1.")
        }
    }
}

#Preview {
    TimerPlaceholderView()
}
