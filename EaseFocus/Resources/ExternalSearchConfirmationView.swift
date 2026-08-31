import SwiftUI

struct ExternalSearchConfirmationView: View {
    let query: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("“\(query)”")
                        .font(FocusTypography.body)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("externalSearchQueryPreview")
                } header: {
                    Text("Search Google for")
                }

                Section {
                    Text(ExternalSearchPrivacyCopy.body)
                        .font(FocusTypography.footnote)
                }
            }
            .navigationTitle(ExternalSearchPrivacyCopy.confirmationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ExternalSearchPrivacyCopy.cancelAction, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(ExternalSearchPrivacyCopy.confirmAction, action: onConfirm)
                        .accessibilityIdentifier("confirmSearchGoogle")
                }
            }
        }
    }
}

extension View {
    func externalSearchConfirmation(_ request: Binding<ExternalSearchRequest?>) -> some View {
        modifier(ExternalSearchConfirmationModifier(request: request))
    }
}

private struct ExternalSearchConfirmationModifier: ViewModifier {
    @Binding var request: ExternalSearchRequest?
    @Environment(\.externalURLOpener) private var opener

    func body(content: Content) -> some View {
        content.sheet(item: $request) { pending in
            ExternalSearchConfirmationView(
                query: pending.query,
                onConfirm: {
                    ExternalSearchOpening.confirm(query: pending.query, opener: opener)
                    request = nil
                },
                onCancel: {
                    request = nil
                }
            )
            #if os(iOS)
            .presentationDetents([.medium, .large])
            #endif
        }
    }
}
