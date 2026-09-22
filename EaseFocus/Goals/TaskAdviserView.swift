import SwiftUI

struct TaskAdviserView: View {
    @Environment(\.locale) private var locale
    @Environment(\.foundationModelClient) private var foundationModelClient

    var body: some View {
        CreatePlanView(
            availability: foundationModelClient.currentAvailability(locale: locale),
            isEmbedded: true
        )
        .focusScreen()
    }
}

#Preview {
    TaskAdviserView()
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
