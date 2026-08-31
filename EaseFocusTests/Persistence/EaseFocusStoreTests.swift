import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct EaseFocusStoreTests {
    private enum OpenFailure: Error {
        case expected
    }

    @Test
    func usesTheDedicatedSwiftDataStoreName() {
        #expect(EaseFocusStore.storeFileName == "easefocus.store")
    }

    @Test
    func productStoreURLUsesTheDedicatedStoreName() throws {
        let url = try EaseFocusStore.productStoreURL()
        #expect(url.lastPathComponent == EaseFocusStore.storeFileName)
    }

    @Test
    func productFilesContainOnlyTheSwiftDataStoreAndSidecars() {
        #expect(
            EaseFocusStore.productStoreFileNames
                == ["easefocus.store", "easefocus.store-wal", "easefocus.store-shm"]
        )
    }

    @Test
    func failedOpenPreservesEveryExistingStoreFile() throws {
        try withTemporaryDirectory { directory in
            let storeURL = directory.appending(path: EaseFocusStore.storeFileName)
            let sentinelFileName = "unrelated-user-data.bin"
            let expectedFiles = EaseFocusStore.productStoreFileNames
                + [sentinelFileName]

            for (index, name) in expectedFiles.enumerated() {
                try Data("original-\(index)".utf8).write(
                    to: directory.appending(path: name)
                )
            }

            #expect(throws: OpenFailure.expected) {
                _ = try EaseFocusStore.makeContainer(at: storeURL) { _ in
                    throw OpenFailure.expected
                }
            }

            for (index, name) in expectedFiles.enumerated() {
                let data = try Data(contentsOf: directory.appending(path: name))
                #expect(data == Data("original-\(index)".utf8))
            }
        }
    }

    @Test
    @MainActor
    func reopensAnExistingProductStoreNormally() throws {
        try withTemporaryDirectory { directory in
            let storeURL = directory.appending(path: EaseFocusStore.storeFileName)
            do {
                let container = try EaseFocusStore.makeContainer(at: storeURL)
                container.mainContext.insert(GoalPlan(title: "Existing plan"))
                try container.mainContext.save()
            }

            let reopened = try EaseFocusStore.makeContainer(at: storeURL)
            let plans = try reopened.mainContext.fetch(FetchDescriptor<GoalPlan>())
            #expect(plans.map(\.title) == ["Existing plan"])
        }
    }

    @Test
    func developmentImportNeverOverwritesExistingSandboxedStore() throws {
        try withTemporaryDirectory { directory in
            let sourceDirectory = directory.appending(path: "source", directoryHint: .isDirectory)
            let destinationDirectory = directory.appending(path: "destination", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

            let source = sourceDirectory.appending(path: EaseFocusStore.storeFileName)
            let destination = destinationDirectory.appending(path: EaseFocusStore.storeFileName)
            let destinationData = Data("valid sandboxed data".utf8)
            try Data(repeating: 1, count: 1_024).write(to: source)
            try destinationData.write(to: destination)

            try EaseFocusStore.copyUnsandboxedStoreIfNeeded(
                source: source,
                destination: destination
            )

            #expect(try Data(contentsOf: destination) == destinationData)
        }
    }

    @Test
    func developmentImportCopiesOnlyProductStoreFilesIntoAnEmptyDestination() throws {
        try withTemporaryDirectory { directory in
            let sourceDirectory = directory.appending(path: "source", directoryHint: .isDirectory)
            let destinationDirectory = directory.appending(path: "destination", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

            for name in EaseFocusStore.productStoreFileNames {
                try Data(name.utf8).write(to: sourceDirectory.appending(path: name))
            }
            let sentinelData = Data("unrelated data must remain untouched".utf8)
            let destinationSentinel = destinationDirectory.appending(path: "unrelated-user-data.bin")
            try sentinelData.write(to: destinationSentinel)

            try EaseFocusStore.copyUnsandboxedStoreIfNeeded(
                source: sourceDirectory.appending(path: EaseFocusStore.storeFileName),
                destination: destinationDirectory.appending(path: EaseFocusStore.storeFileName)
            )

            for name in EaseFocusStore.productStoreFileNames {
                #expect(
                    try Data(contentsOf: destinationDirectory.appending(path: name))
                        == Data(name.utf8)
                )
            }
            #expect(try Data(contentsOf: destinationSentinel) == sentinelData)
        }
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

    private func withTemporaryDirectory(
        _ body: (URL) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "EaseFocusStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Could not remove test directory: \(error)")
            }
        }
        try body(directory)
    }
}
