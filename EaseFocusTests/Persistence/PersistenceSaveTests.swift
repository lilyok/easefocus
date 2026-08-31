import Foundation
import Testing
@testable import EaseFocus

struct PersistenceSaveTests {
    private enum SampleError: Error, LocalizedError {
        case diskFull

        var errorDescription: String? {
            "The disk is full."
        }
    }

    @Test
    func explainsAFailedSaveWithoutSwallowingTheUnderlyingError() {
        let result = PersistenceSaving.result {
            throw SampleError.diskFull
        }

        guard case .failed(let message) = result else {
            Issue.record("Expected a failed save result")
            return
        }
        #expect(message.contains("could not save"))
        #expect(message.contains("The disk is full."))
        #expect(PersistenceSaveCopy.title.contains("Couldn't save"))
        #expect(PersistenceSaveCopy.retry == "Try again")
        #expect(PersistenceSaveCopy.discard == "Discard changes")
    }

    @Test
    func reportsSuccessWhenASaveCompletes() {
        #expect(PersistenceSaving.result {} == .saved)
    }

    @Test
    func rollsBackAFailedMutationSoRetryCanReapplyIt() {
        var value = 0
        var rolledBack = false

        let result = PersistenceSaving.commit(
            apply: { value = 1 },
            save: { throw SampleError.diskFull },
            rollback: {
                value = 0
                rolledBack = true
            }
        )

        #expect(result != .saved)
        #expect(value == 0)
        #expect(rolledBack)

        let retried = PersistenceSaving.commit(
            apply: { value = 1 },
            save: {},
            rollback: { value = 0 }
        )
        #expect(retried == .saved)
        #expect(value == 1)
    }
}
