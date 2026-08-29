import Darwin
import Foundation
import SwiftData

nonisolated enum EaseFocusStore {
    static let storeFileName = "easefocus.store"
    static let legacyCoreDataFileName = "pomodoro.sqlite"

    /// Lightweight migration only. Never deletes `pomodoro.sqlite`.
    static let allowsDestructiveSchemaCutover = false

    static var productStoreFileNames: [String] {
        [storeFileName, storeFileName + "-wal", storeFileName + "-shm"]
    }

    static var schema: Schema {
        Schema([GoalPlan.self, PlanTask.self, FocusSession.self])
    }

    static func makeContainer() throws -> ModelContainer {
        importUnsandboxedStoreIfNeeded()
        do {
            return try openContainer()
        } catch {
            try? removeProductStoreFiles()
            importUnsandboxedStoreIfNeeded()
            return try openContainer()
        }
    }

    static func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func openContainer() throws -> ModelContainer {
        let storeURL = try productStoreURL()
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [configuration])
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

    static func importUnsandboxedStoreIfNeeded() {
        do {
            try copyUnsandboxedStoreIfNeeded()
        } catch {
            return
        }
    }

    private static func copyUnsandboxedStoreIfNeeded() throws {
        let destination = try productStoreURL()
        guard let source = unsandboxedStoreURL() else {
            return
        }
        let fileManager = FileManager.default
        guard source.standardizedFileURL != destination.standardizedFileURL,
              fileManager.fileExists(atPath: source.path) else {
            return
        }

        let sourceSize = fileSize(at: source)
        let destinationSize = fileSize(at: destination)
        guard sourceSize > 0, sourceSize > destinationSize else {
            return
        }

        let sourceDirectory = source.deletingLastPathComponent()
        let destinationDirectory = destination.deletingLastPathComponent()
        let tempDirectory = destinationDirectory.appending(path: ".easefocus-import", directoryHint: .isDirectory)
        try? fileManager.removeItem(at: tempDirectory)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }

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
            let to = destinationDirectory.appending(path: name, directoryHint: .notDirectory)
            if fileManager.fileExists(atPath: to.path) {
                try fileManager.removeItem(at: to)
            }
            let staged = tempDirectory.appending(path: name, directoryHint: .notDirectory)
            if fileManager.fileExists(atPath: staged.path) {
                try fileManager.copyItem(at: staged, to: to)
            }
        }
    }

    static func removeProductStoreFiles() throws {
        let directory = try applicationSupportDirectory()
        let fileManager = FileManager.default
        for name in productStoreFileNames {
            let url = directory.appending(path: name, directoryHint: .notDirectory)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
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
