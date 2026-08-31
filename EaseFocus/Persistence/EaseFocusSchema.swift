import Foundation
import SwiftData

enum EaseFocusSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [GoalPlan.self, PlanTask.self, FocusSession.self]
    }

    @Model
    final class GoalPlan {
        var id: UUID
        var title: String
        var details: String?
        var createdAt: Date
        var updatedAt: Date
        var status: PlanStatus
        var source: PlanSource
        var preferredLocaleIdentifier: String
        var surveySnapshot: Data?

        @Relationship(deleteRule: .cascade, inverse: \PlanTask.plan)
        var tasks: [PlanTask]

        init(
            id: UUID = UUID(),
            title: String,
            details: String? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            status: PlanStatus = .active,
            source: PlanSource = .manual,
            preferredLocaleIdentifier: String = Locale.current.identifier,
            surveySnapshot: Data? = nil,
            tasks: [PlanTask] = []
        ) {
            self.id = id
            self.title = title
            self.details = details
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.status = status
            self.source = source
            self.preferredLocaleIdentifier = preferredLocaleIdentifier
            self.surveySnapshot = surveySnapshot
            self.tasks = tasks
        }
    }

    @Model
    final class PlanTask {
        var id: UUID
        var title: String
        var details: String?
        var position: Int
        var estimatedPomodoros: Int
        var status: TaskStatus
        var createdAt: Date
        var updatedAt: Date
        var completedAt: Date?
        var plan: GoalPlan?
        var searchQuery: String?

        @Relationship(deleteRule: .cascade, inverse: \FocusSession.task)
        var sessions: [FocusSession]

        init(
            id: UUID = UUID(),
            title: String,
            details: String? = nil,
            position: Int,
            estimatedPomodoros: Int = 1,
            status: TaskStatus = .pending,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            completedAt: Date? = nil,
            sessions: [FocusSession] = [],
            searchQuery: String? = nil
        ) {
            self.id = id
            self.title = title
            self.details = details
            self.position = position
            self.estimatedPomodoros = max(1, estimatedPomodoros)
            self.status = status
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.completedAt = completedAt
            self.sessions = sessions
            self.searchQuery = searchQuery
        }
    }

    @Model
    final class FocusSession {
        var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var plannedDurationSeconds: Int
        var elapsedSeconds: Int
        var outcome: SessionOutcome?
        var interruptionNote: String?
        var task: PlanTask?

        init(
            id: UUID = UUID(),
            startedAt: Date = .now,
            endedAt: Date? = nil,
            plannedDurationSeconds: Int,
            elapsedSeconds: Int = 0,
            outcome: SessionOutcome? = nil,
            interruptionNote: String? = nil
        ) {
            self.id = id
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.plannedDurationSeconds = plannedDurationSeconds
            self.elapsedSeconds = elapsedSeconds
            self.outcome = outcome
            self.interruptionNote = interruptionNote
        }
    }
}

enum EaseFocusSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [GoalPlan.self, PlanTask.self, FocusSession.self, PlanRevision.self]
    }
}

enum EaseFocusMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [EaseFocusSchemaV1.self, EaseFocusSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: EaseFocusSchemaV1.self,
        toVersion: EaseFocusSchemaV2.self
    )
}
