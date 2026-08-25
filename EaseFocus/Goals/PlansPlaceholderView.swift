import SwiftUI

struct PlansPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Plans", systemImage: "list.bullet.rectangle")
            } description: {
                Text("Manual and generated plans will live here in Phase 1.")
            }
            .navigationTitle("Plans")
        }
    }
}

#Preview {
    PlansPlaceholderView()
}
