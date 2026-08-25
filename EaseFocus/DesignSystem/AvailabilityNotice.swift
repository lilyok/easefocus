import SwiftUI

struct AvailabilityNotice: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "sparkles")
        } description: {
            Text(message)
        }
        .foregroundStyle(Color.focusPrimary)
    }
}

#Preview {
    AvailabilityNotice(
        title: "Apple Intelligence unavailable",
        message: "You can still create a plan manually."
    )
}
