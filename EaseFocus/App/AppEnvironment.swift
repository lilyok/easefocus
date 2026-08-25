import SwiftUI

struct FoundationModelClientKey: EnvironmentKey {
    static let defaultValue: any FoundationModelGenerating = LiveFoundationModelClient()
}

extension EnvironmentValues {
    var foundationModelClient: any FoundationModelGenerating {
        get { self[FoundationModelClientKey.self] }
        set { self[FoundationModelClientKey.self] = newValue }
    }
}
