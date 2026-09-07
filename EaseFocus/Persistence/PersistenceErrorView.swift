import SwiftUI

struct PersistenceErrorView: View {
    let error: Error?

    var body: some View {
        ContentUnavailableView {
            Label(PersistenceErrorCopy.title, systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            VStack(spacing: FocusSpacing.small) {
                Text(PersistenceErrorCopy.preserved)
                Text(PersistenceErrorCopy.retryHint)
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
