import Foundation
import Testing
@testable import EaseFocus

struct AppleIntelligenceSettingsTests {
    @Test
    func opensTheAppleIntelligenceSettingsPane() throws {
        let url = try #require(AppleIntelligenceSettingsURL.make())

        #if os(macOS)
        #expect(url.scheme == "x-apple.systempreferences")
        #expect(url.absoluteString.contains("Siri-Settings"))
        #else
        #expect(url.scheme?.lowercased() == "app-prefs")
        #expect(url.absoluteString.contains("SIRI"))
        #endif
    }

    @Test
    func offersASettingsLinkWhenAppleIntelligenceIsOffOrDownloading() {
        #expect(FoundationModelAvailability.unavailable(.appleIntelligenceNotEnabled).canOpenAppleIntelligenceSettings)
        #expect(FoundationModelAvailability.unavailable(.modelNotReady).canOpenAppleIntelligenceSettings)
        #expect(!FoundationModelAvailability.unavailable(.deviceNotEligible).canOpenAppleIntelligenceSettings)
        #expect(!FoundationModelAvailability.available.canOpenAppleIntelligenceSettings)
    }

    @Test
    func showsTheSurveyUnlessTheDeviceCannotRunAppleIntelligence() {
        #expect(FoundationModelAvailability.available.showsPlanSurvey)
        #expect(FoundationModelAvailability.unavailable(.appleIntelligenceNotEnabled).showsPlanSurvey)
        #expect(FoundationModelAvailability.unavailable(.modelNotReady).showsPlanSurvey)
        #expect(!FoundationModelAvailability.unavailable(.deviceNotEligible).showsPlanSurvey)
    }
}
