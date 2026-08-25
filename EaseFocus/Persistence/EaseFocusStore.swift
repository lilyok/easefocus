import Foundation
import SwiftData

nonisolated enum EaseFocusStore {
    static let storeFileName = "easefocus.store"
    static let legacyCoreDataFileName = "pomodoro.sqlite"

    static var schema: Schema {
        Schema([GoalPlan.self, PlanTask.self, FocusSession.self])
    }

    static func makeContainer() throws -> ModelContainer {
        do {
            return try openContainer()
        } catch {
            try removeProductStoreFiles()
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

    static func removeProductStoreFiles() throws {
        let directory = try applicationSupportDirectory()
        let fileManager = FileManager.default
        for name in [storeFileName, storeFileName + "-wal", storeFileName + "-shm"] {
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
