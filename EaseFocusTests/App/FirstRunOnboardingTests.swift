import Foundation
import Testing
@testable import EaseFocus

struct FirstRunOnboardingTests {
    @Test
    func persistsCompletionInUserDefaults() {
        #expect(FirstRunOnboarding.completedKey == "easefocus.onboarding.completed")
    }
}
