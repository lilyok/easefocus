import Foundation
import Testing
@testable import EaseFocus

struct EaseFocusStoreTests {
    @Test
    func usesAStoreNameThatDoesNotCollideWithTheLegacyCoreDataFile() {
        #expect(EaseFocusStore.storeFileName == "easefocus.store")
        #expect(EaseFocusStore.legacyCoreDataFileName == "pomodoro.sqlite")
        #expect(EaseFocusStore.storeFileName != EaseFocusStore.legacyCoreDataFileName)
    }
}
