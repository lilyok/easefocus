import Foundation

nonisolated enum AppleIntelligenceSettingsURL {
    static func make() -> URL? {
        #if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")
        #else
        URL(string: "App-prefs:root=SIRI")
        #endif
    }
}
