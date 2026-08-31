import Foundation
import Testing
@testable import EaseFocus

struct PlanSnapshotTests {
    @Test
    func roundTripsAPlanAndItsOrderedTasks() throws {
        let firstID = UUID()
        let secondID = UUID()
        let snapshot = PlanSnapshot(
            id: UUID(),
            title: "Spanish greetings",
            details: "A short speaking plan.",
            status: .active,
            tasks: [
                TaskSnapshot(
                    id: firstID,
                    title: "Practice hola",
                    details: "Say hello",
                    position: 0,
                    estimatedPomodoros: 1,
                    status: .completed,
                    searchQuery: "Spanish greetings audio"
                ),
                TaskSnapshot(
                    id: secondID,
                    title: "Record a greeting",
                    details: nil,
                    position: 1,
                    estimatedPomodoros: 2,
                    status: .pending,
                    searchQuery: nil
                ),
            ]
        )

        let data = try PlanSnapshotCoding.encode(snapshot)
        let decoded = try PlanSnapshotCoding.decode(data)

        #expect(decoded == snapshot)
        #expect(decoded.tasks.map(\.id) == [firstID, secondID])
        #expect(decoded.tasks.map(\.position) == [0, 1])
        #expect(decoded.tasks.first?.searchQuery == "Spanish greetings audio")
        #expect(decoded.tasks.last?.searchQuery == nil)
    }

    @Test
    func rejectsDuplicateTaskIDsAndInvalidOrdering() {
        let id = UUID()
        let planID = UUID()
        let duplicate = PlanSnapshot(
            id: planID,
            title: "Plan",
            details: nil,
            status: .active,
            tasks: [
                TaskSnapshot(id: id, title: "A", details: nil, position: 0, estimatedPomodoros: 1, status: .pending, searchQuery: nil),
                TaskSnapshot(id: id, title: "B", details: nil, position: 1, estimatedPomodoros: 1, status: .pending, searchQuery: nil),
            ]
        )
        #expect(throws: PlanRevisionFactoryError.duplicateTaskIDs) {
            _ = try duplicate.validated()
        }

        let uniqueID = UUID()
        let gapped = PlanSnapshot(
            id: planID,
            title: "Plan",
            details: nil,
            status: .active,
            tasks: [
                TaskSnapshot(id: uniqueID, title: "A", details: nil, position: 0, estimatedPomodoros: 1, status: .pending, searchQuery: nil),
                TaskSnapshot(id: UUID(), title: "B", details: nil, position: 2, estimatedPomodoros: 1, status: .pending, searchQuery: nil),
            ]
        )
        #expect(throws: PlanRevisionFactoryError.invalidOrdering) {
            _ = try gapped.validated()
        }
    }

    @Test
    func reportsDecodingFailuresInsteadOfSwallowingThem() {
        #expect(throws: PlanSnapshotCodingError.decodingFailed) {
            _ = try PlanSnapshotCoding.decode(Data("not-json".utf8))
        }
    }
}
