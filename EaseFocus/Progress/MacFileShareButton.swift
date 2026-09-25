import SwiftUI
#if os(macOS)
import AppKit

/// macOS share control using `NSSharingServicePicker`.
/// SwiftUI `ShareLink` freezes Notes for this payload on Mac.
/// Photos destinations are filtered out — they do not import reliably here.
struct MacFileShareButton<Label: View>: View {
    let fileURL: URL
    @ViewBuilder var label: () -> Label

    @StateObject private var anchor = SharePickerAnchorModel()

    var body: some View {
        Button {
            present()
        } label: {
            label()
        }
        .background(
            SharePickerAnchorView(model: anchor)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
    }

    private func present() {
        let absolute = URL(fileURLWithPath: fileURL.path)
        // File URL gives the system share popover a real preview thumbnail.
        // (NSImage-only hid the preview; image+file broke Freeform.)
        anchor.present(items: [absolute])
    }
}

@MainActor
final class SharePickerAnchorModel: ObservableObject {
    weak var view: NSView?
    private var coordinator: SharePickerCoordinator?

    func present(items: [Any]) {
        guard let view else {
            return
        }
        let show = { [weak self] in
            guard let self else {
                return
            }
            let coordinator = SharePickerCoordinator()
            self.coordinator = coordinator
            EaseFocusWindow.suspendDuplicateGuarding()
            let picker = NSSharingServicePicker(items: items)
            picker.delegate = coordinator
            view.window?.makeFirstResponder(nil)
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
        if view.window == nil {
            DispatchQueue.main.async(execute: show)
        } else {
            show()
        }
    }
}

private final class SharePickerCoordinator: NSObject, NSSharingServicePickerDelegate, NSSharingServiceDelegate {
    func sharingServicePicker(
        _ sharingServicePicker: NSSharingServicePicker,
        sharingServicesForItems items: [Any],
        proposedSharingServices proposedServices: [NSSharingService]
    ) -> [NSSharingService] {
        proposedServices.filter { service in
            !service.title.lowercased().contains("photo")
        }
    }

    func sharingServicePicker(
        _ sharingServicePicker: NSSharingServicePicker,
        didChoose service: NSSharingService?
    ) {
        guard let service else {
            // Picker dismissed without a destination.
            EaseFocusWindow.resumeDuplicateGuarding()
            return
        }
        service.delegate = self
        // Keep guarding suspended while Freeform / Journal sheets are up.
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        EaseFocusWindow.resumeDuplicateGuarding()
    }

    func sharingService(
        _ sharingService: NSSharingService,
        didFailToShareItems items: [Any],
        error: Error
    ) {
        EaseFocusWindow.resumeDuplicateGuarding()
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Couldn’t share"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}

private struct SharePickerAnchorView: NSViewRepresentable {
    @ObservedObject var model: SharePickerAnchorModel

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            model.view = view
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        model.view = nsView
    }
}
#endif
