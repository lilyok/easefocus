import SwiftUI

struct FoundationModelClientKey: EnvironmentKey {
    static let defaultValue: any FoundationModelGenerating = LiveFoundationModelClient()
}

struct ExternalURLOpenerKey: EnvironmentKey {
    static let defaultValue: any ExternalURLOpening = SystemExternalURLOpener()
}

extension EnvironmentValues {
    var foundationModelClient: any FoundationModelGenerating {
        get { self[FoundationModelClientKey.self] }
        set { self[FoundationModelClientKey.self] = newValue }
    }

    var externalURLOpener: any ExternalURLOpening {
        get { self[ExternalURLOpenerKey.self] }
        set { self[ExternalURLOpenerKey.self] = newValue }
    }
}
