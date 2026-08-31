import Foundation

nonisolated struct PlanSnapshot: Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var details: String?
    var status: PlanStatus
    var tasks: [TaskSnapshot]

    static func capturing(_ plan: GoalPlan) -> PlanSnapshot {
        PlanSnapshot(
            id: plan.id,
            title: plan.title,
            details: plan.details,
            status: plan.status,
            tasks: plan.orderedTasks.map(TaskSnapshot.capturing)
        )
    }

    func validated() throws -> PlanSnapshot {
        let ids = tasks.map(\.id)
        guard Set(ids).count == ids.count else {
            throw PlanRevisionFactoryError.duplicateTaskIDs
        }

        let ordered = tasks.sorted { $0.position < $1.position }
        let positions = ordered.map(\.position)
        let expected = Array(0..<ordered.count)
        guard positions == expected else {
            throw PlanRevisionFactoryError.invalidOrdering
        }

        return PlanSnapshot(
            id: id,
            title: title,
            details: details,
            status: status,
            tasks: ordered
        )
    }
}

nonisolated struct TaskSnapshot: Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var details: String?
    var position: Int
    var estimatedPomodoros: Int
    var status: TaskStatus
    var searchQuery: String?

    static func capturing(_ task: PlanTask) -> TaskSnapshot {
        TaskSnapshot(
            id: task.id,
            title: task.title,
            details: task.details,
            position: task.position,
            estimatedPomodoros: task.estimatedPomodoros,
            status: task.status,
            searchQuery: task.searchQuery
        )
    }

    func matchesCompletedWork(_ original: TaskSnapshot) -> Bool {
        matchesProtectedWork(original)
            && status == .completed
            && original.status == .completed
    }

    func matchesProtectedWork(_ original: TaskSnapshot) -> Bool {
        id == original.id
            && title == original.title
            && details == original.details
            && estimatedPomodoros == original.estimatedPomodoros
            && status == original.status
            && searchQuery == original.searchQuery
    }
}

nonisolated enum PlanSnapshotCodingError: Equatable, Error {
    case encodingFailed
    case decodingFailed
}

nonisolated enum PlanSnapshotCoding {
    static func encode(_ snapshot: PlanSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(snapshot)
        } catch {
            throw PlanSnapshotCodingError.encodingFailed
        }
    }

    static func decode(_ data: Data) throws -> PlanSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(PlanSnapshot.self, from: data)
        } catch {
            throw PlanSnapshotCodingError.decodingFailed
        }
    }
}
