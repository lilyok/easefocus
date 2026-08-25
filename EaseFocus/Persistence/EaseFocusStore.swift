import Foundation
import SwiftData

/// Owns the SwiftData store location for EaseFocus.
///
/// The old Pomodoro app keeps `pomodoro.sqlite` in Application Support via
/// `NSPersistentCloudKitContainer(name: "pomodoro")`. This store uses a
/// different filename and never opens, moves, or deletes that file.
nonisolated enum EaseFocusStore {
    static let storeFileName = "easefocus.store"
    static let legacyCoreDataFileName = "pomodoro.sqlite"

    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([FocusItem.self])
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let storeURL = directory.appending(path: storeFileName, directoryHint: .notDirectory)
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
