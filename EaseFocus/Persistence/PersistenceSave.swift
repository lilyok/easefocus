import SwiftData
import SwiftUI

nonisolated enum PersistenceSaveCopy {
    static let title = LocalizedCopy("Couldn't save your data")
    static let message = LocalizedCopy(
        "EaseFocus could not save your latest changes. Try again. If this keeps happening, quit other EaseFocus copies and restart the app."
    )
    static let retry = LocalizedCopy("Try again")
    static let discard = LocalizedCopy("Discard changes")
    static let later = LocalizedCopy("Later")

    static func message(for error: Error) -> String {
        "\(message.localized())\n\n\(error.localizedDescription)"
    }
}

nonisolated enum PersistenceMutationResult: Equatable {
    case saved
    case failed(String)
}

nonisolated enum PersistenceSaving {
    static func result(of save: () throws -> Void) -> PersistenceMutationResult {
        do {
            try save()
            return .saved
        } catch {
            return .failed(PersistenceSaveCopy.message(for: error))
        }
    }
}

extension View {
    func persistenceSaveAlert(
        isPresented: Binding<Bool>,
        message: String?,
        onRetry: @escaping () -> Void,
        onDiscard: (() -> Void)? = nil,
        onDefer: (() -> Void)? = nil
    ) -> some View {
        alert(Text(PersistenceSaveCopy.title), isPresented: isPresented) {
            Button(PersistenceSaveCopy.retry, action: onRetry)
            if let onDiscard {
                Button(PersistenceSaveCopy.discard, role: .cancel, action: onDiscard)
            } else if let onDefer {
                Button(PersistenceSaveCopy.later, role: .cancel, action: onDefer)
            }
        } message: {
            Text(message ?? PersistenceSaveCopy.message.localized())
        }
        .accessibilityIdentifier("persistenceSaveError")
    }
}
