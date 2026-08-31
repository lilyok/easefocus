import Foundation
import SwiftData
import Testing
@testable import EaseFocus

struct SchemaMigrationTests {
    @Test
    @MainActor
    func migratesAVersion1StoreWithoutLosingPlansTasksOrSessions() throws {
        try withTemporaryDirectory { directory in
            let storeURL = directory.appending(path: EaseFocusStore.storeFileName)
            let planID = UUID()
            let pendingID = UUID()
            let completedID = UUID()
            let sessionID = UUID()
            let completedAt = Date(timeIntervalSince1970: 1_700_000_000)

            do {
                let legacy = try EaseFocusStore.makeUnversionedLegacyContainer(at: storeURL)
                let plan = EaseFocusSchemaV1.GoalPlan(
                    id: planID,
                    title: "Spanish greetings",
                    details: "A short speaking plan.",
                    source: .generated,
                    preferredLocaleIdentifier: "es-ES"
                )
                let pending = EaseFocusSchemaV1.PlanTask(
                    id: pendingID,
                    title: "Practice hola",
                    position: 0,
                    searchQuery: "Spanish greetings audio"
                )
                let completed = EaseFocusSchemaV1.PlanTask(
                    id: completedID,
                    title: "Record a greeting",
                    position: 1,
                    status: .completed,
                    completedAt: completedAt
                )
                let session = EaseFocusSchemaV1.FocusSession(
                    id: sessionID,
                    startedAt: completedAt,
                    endedAt: completedAt.addingTimeInterval(1_500),
                    plannedDurationSeconds: 1_500,
                    elapsedSeconds: 1_500,
                    outcome: .completed
                )
                session.task = completed
                completed.sessions = [session]
                pending.plan = plan
                completed.plan = plan
                plan.tasks = [pending, completed]
                legacy.mainContext.insert(plan)
                try legacy.mainContext.save()
            }

            let migrated = try EaseFocusStore.makeContainer(at: storeURL)
            let plans = try migrated.mainContext.fetch(FetchDescriptor<GoalPlan>())
            let plan = try #require(plans.first)
            #expect(plans.count == 1)
            #expect(plan.id == planID)
            #expect(plan.title == "Spanish greetings")
            #expect(plan.details == "A short speaking plan.")
            #expect(plan.source == .generated)
            #expect(plan.preferredLocaleIdentifier == "es-ES")
            #expect(plan.orderedTasks.map(\.id) == [pendingID, completedID])
            #expect(plan.orderedTasks.map(\.title) == ["Practice hola", "Record a greeting"])
            #expect(plan.orderedTasks.first?.searchQuery == "Spanish greetings audio")
            #expect(plan.orderedTasks.last?.status == .completed)
            #expect(plan.orderedTasks.last?.completedAt == completedAt)
            #expect(plan.orderedTasks.last?.sessions.map(\.id) == [sessionID])
            #expect(plan.orderedTasks.last?.sessions.first?.outcome == .completed)
            #expect(plan.revisions.isEmpty)

            let before = PlanSnapshot.capturing(plan)
            let after = before
            let revision = try PlanRevisionFactory.make(
                for: plan,
                reason: "Audit trail",
                source: .user,
                changeSummary: "Recorded after migration",
                before: before,
                after: after
            )
            migrated.mainContext.insert(revision)
            try migrated.mainContext.save()
            #expect(plan.orderedRevisions.count == 1)
            #expect(plan.orderedTasks.last?.sessions.count == 1)

            let reopened = try EaseFocusStore.makeContainer(at: storeURL)
            let reopenedPlans = try reopened.mainContext.fetch(FetchDescriptor<GoalPlan>())
            let reopenedPlan = try #require(reopenedPlans.first)
            #expect(reopenedPlan.id == planID)
            #expect(reopenedPlan.orderedRevisions.map(\.reason) == ["Audit trail"])
            #expect(reopenedPlan.orderedTasks.last?.sessions.map(\.id) == [sessionID])
        }
    }

    @Test
    @MainActor
    func failedMigrationLeavesExistingStoreFilesInPlace() throws {
        try withTemporaryDirectory { directory in
            let storeURL = directory.appending(path: EaseFocusStore.storeFileName)
            do {
                let legacy = try EaseFocusStore.makeUnversionedLegacyContainer(at: storeURL)
                legacy.mainContext.insert(EaseFocusSchemaV1.GoalPlan(title: "Keep me"))
                try legacy.mainContext.save()
            }

            var originals: [String: Data] = [:]
            for name in EaseFocusStore.productStoreFileNames {
                let url = directory.appending(path: name)
                if FileManager.default.fileExists(atPath: url.path) {
                    originals[name] = try Data(contentsOf: url)
                }
            }
            #expect(originals[EaseFocusStore.storeFileName] != nil)

            enum OpenFailure: Error { case expected }
            #expect(throws: OpenFailure.expected) {
                _ = try EaseFocusStore.makeContainer(at: storeURL) { _ in
                    throw OpenFailure.expected
                }
            }

            for (name, data) in originals {
                #expect(try Data(contentsOf: directory.appending(path: name)) == data)
            }

            try Data("not-a-sqlite-store".utf8).write(to: storeURL)
            let corrupted = try Data(contentsOf: storeURL)
            #expect(throws: (any Error).self) {
                _ = try EaseFocusStore.makeContainer(at: storeURL)
            }
            #expect(FileManager.default.fileExists(atPath: storeURL.path))
            #expect(try Data(contentsOf: storeURL) == corrupted)
        }
    }

    private func withTemporaryDirectory(
        _ body: (URL) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "EaseFocusSchemaMigrationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
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
