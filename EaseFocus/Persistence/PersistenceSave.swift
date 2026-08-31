import SwiftData
import SwiftUI

nonisolated enum PersistenceSaveCopy {
    static let title = "Couldn't save your data"
    static let message =
        "EaseFocus could not save your latest changes. Try again. If this keeps happening, quit other EaseFocus copies and restart the app."

    static func message(for error: Error) -> String {
        "\(message)\n\n\(error.localizedDescription)"
    }
}

nonisolated enum PersistenceSaving {
    static func result(of save: () throws -> Void) -> String? {
        do {
            try save()
            return nil
        } catch {
            return PersistenceSaveCopy.message(for: error)
        }
    }
}

extension View {
    func persistenceSaveAlert(error: Binding<String?>) -> some View {
        alert(
            PersistenceSaveCopy.title,
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                error.wrappedValue = nil
            }
        } message: {
            Text(error.wrappedValue ?? PersistenceSaveCopy.message)
        }
        .accessibilityIdentifier("persistenceSaveError")
    }
}
