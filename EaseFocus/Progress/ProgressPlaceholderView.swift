import SwiftUI

struct ProgressPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text("Session history and weekly summaries will appear here later.")
            }
            .navigationTitle("Progress")
        }
    }
}

#Preview {
    ProgressPlaceholderView()
}
