import SwiftUI

struct FoundationModelClientKey: EnvironmentKey {
    static let defaultValue: any FoundationModelGenerating = LiveFoundationModelClient()
}

struct PlanRefinementClientKey: EnvironmentKey {
    static let defaultValue: any PlanRefinementGenerating = LivePlanRefinementClient()
}

struct ExternalURLOpenerKey: EnvironmentKey {
    static let defaultValue: any ExternalURLOpening = SystemExternalURLOpener()
}

extension EnvironmentValues {
    var foundationModelClient: any FoundationModelGenerating {
        get { self[FoundationModelClientKey.self] }
        set { self[FoundationModelClientKey.self] = newValue }
    }

    var planRefinementClient: any PlanRefinementGenerating {
        get { self[PlanRefinementClientKey.self] }
        set { self[PlanRefinementClientKey.self] = newValue }
    }

    var externalURLOpener: any ExternalURLOpening {
        get { self[ExternalURLOpenerKey.self] }
        set { self[ExternalURLOpenerKey.self] = newValue }
    }
}
