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

    @Test
    func doesNotDestructivelyCutOverOncePlansCanExist() {
        #expect(!EaseFocusStore.allowsDestructiveSchemaCutover)
        #expect(EaseFocusStore.productStoreFileNames.contains(EaseFocusStore.storeFileName))
        #expect(!EaseFocusStore.productStoreFileNames.contains(EaseFocusStore.legacyCoreDataFileName))
    }

    @Test
    func treatsAMissingOrEmptyStoreAsZeroBytes() {
        let missing = URL(fileURLWithPath: "/tmp/easefocus-missing-\(UUID().uuidString).store")
        #expect(EaseFocusStore.fileSize(at: missing) == 0)
    }

    @Test
    func unsandboxedStoreURLUsesTheRealHomeApplicationSupport() throws {
        let url = try #require(EaseFocusStore.unsandboxedStoreURL())
        #expect(url.lastPathComponent == EaseFocusStore.storeFileName)
        #expect(url.path.contains("Application Support"))
        #expect(!url.path.contains("/Containers/"))
    }
}
