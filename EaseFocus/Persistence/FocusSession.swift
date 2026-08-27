import Foundation
import SwiftData

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

    var isOpen: Bool {
        endedAt == nil && outcome == nil
    }

    func finish(outcome: SessionOutcome, at date: Date, elapsedSeconds: Int, note: String? = nil) {
        self.outcome = outcome
        endedAt = date
        self.elapsedSeconds = max(0, elapsedSeconds)
        interruptionNote = note
    }
}
