import Darwin
import Foundation
import SwiftData

nonisolated enum EaseFocusStore {
    static let storeFileName = "easefocus.store"

    static var productStoreFileNames: [String] {
        [storeFileName, storeFileName + "-wal", storeFileName + "-shm"]
    }

    static var schema: Schema {
        Schema(versionedSchema: EaseFocusSchemaV2.self)
    }

    static var v1Schema: Schema {
        Schema(versionedSchema: EaseFocusSchemaV1.self)
    }

    static func makeContainer() throws -> ModelContainer {
        #if DEBUG
        // Development builds may import a pre-sandbox store once, but never replace
        // any existing sandboxed store file. Release builds do not perform this import.
        try importUnsandboxedStoreIfNeeded()
        #endif
        let storeURL = try productStoreURL()
        return try makeContainer(at: storeURL)
    }

    static func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: EaseFocusMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func makeV1Container(at storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: v1Schema, url: storeURL)
        return try ModelContainer(for: v1Schema, configurations: [configuration])
    }

    private static func openContainer(at storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(
            for: schema,
            migrationPlan: EaseFocusMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func makeContainer(at storeURL: URL) throws -> ModelContainer {
        try makeContainer(at: storeURL, opener: openContainer(at:))
    }

    static func makeContainer(
        at storeURL: URL,
        opener: (URL) throws -> ModelContainer
    ) throws -> ModelContainer {
        try opener(storeURL)
    }

    static func productStoreURL() throws -> URL {
        try applicationSupportDirectory().appending(path: storeFileName, directoryHint: .notDirectory)
    }

    static func unsandboxedStoreURL() -> URL? {
        guard let pw = getpwuid(getuid()) else {
            return nil
        }
        let home = String(cString: pw.pointee.pw_dir)
        return URL(fileURLWithPath: home, isDirectory: true)
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
            .appending(path: storeFileName, directoryHint: .notDirectory)
    }

    static func fileSize(at url: URL) -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return 0
        }
        return (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    }

    static func importUnsandboxedStoreIfNeeded() throws {
        let destination = try productStoreURL()
        guard let source = unsandboxedStoreURL() else {
            return
        }
        try copyUnsandboxedStoreIfNeeded(source: source, destination: destination)
    }

    static func copyUnsandboxedStoreIfNeeded(source: URL, destination: URL) throws {
        let fileManager = FileManager.default
        guard source.standardizedFileURL != destination.standardizedFileURL,
              fileManager.fileExists(atPath: source.path) else {
            return
        }

        let sourceDirectory = source.deletingLastPathComponent()
        let destinationDirectory = destination.deletingLastPathComponent()
        let destinationAlreadyExists = productStoreFileNames.contains { name in
            fileManager.fileExists(
                atPath: destinationDirectory
                    .appending(path: name, directoryHint: .notDirectory)
                    .path
            )
        }
        guard fileSize(at: source) > 0, !destinationAlreadyExists else {
            return
        }

        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let tempDirectory = destinationDirectory.appending(
            path: ".easefocus-import-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            do {
                try fileManager.removeItem(at: tempDirectory)
            } catch {
                assertionFailure("Could not remove temporary store import: \(error)")
            }
        }

        for name in productStoreFileNames {
            let from = sourceDirectory.appending(path: name, directoryHint: .notDirectory)
            guard fileManager.fileExists(atPath: from.path), fileSize(at: from) > 0 || name == storeFileName else {
                continue
            }
            try fileManager.copyItem(
                at: from,
                to: tempDirectory.appending(path: name, directoryHint: .notDirectory)
            )
        }

        let stagedStore = tempDirectory.appending(path: storeFileName, directoryHint: .notDirectory)
        guard fileSize(at: stagedStore) > 0 else {
            return
        }

        for name in productStoreFileNames {
            let staged = tempDirectory.appending(path: name, directoryHint: .notDirectory)
            if fileManager.fileExists(atPath: staged.path) {
                try fileManager.copyItem(
                    at: staged,
                    to: destinationDirectory.appending(path: name, directoryHint: .notDirectory)
                )
            }
        }
    }

    private static func applicationSupportDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }
}
