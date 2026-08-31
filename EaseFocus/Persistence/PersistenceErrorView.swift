import SwiftUI

struct PersistenceErrorView: View {
    let error: Error?

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't open your data", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            VStack(spacing: FocusSpacing.small) {
                Text("EaseFocus could not open easefocus.store. Your store files were preserved.")
                Text("Quit any other EaseFocus copies and try again. If the problem continues, keep the store files and contact support.")
                if let error {
                    Text(error.localizedDescription)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.focusBackground)
        .accessibilityIdentifier("persistenceError")
    }
}

#Preview {
    PersistenceErrorView(error: nil)
}
