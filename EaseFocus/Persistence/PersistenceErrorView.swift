import SwiftUI

struct PersistenceErrorView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Couldn't open your data", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("EaseFocus could not open easefocus.store. The old Pomodoro file was not changed.")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.focusBackground)
    }
}

#Preview {
    PersistenceErrorView()
}
