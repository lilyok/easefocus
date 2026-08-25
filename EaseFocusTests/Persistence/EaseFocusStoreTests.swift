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

    @Test
    func productStoreURLNeverUsesTheLegacyFileName() throws {
        let url = try EaseFocusStore.productStoreURL()
        #expect(url.lastPathComponent == EaseFocusStore.storeFileName)
        #expect(url.lastPathComponent != EaseFocusStore.legacyCoreDataFileName)
    }
}
