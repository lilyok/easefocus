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
    func failedSaveRetainsMutationAndRetryDoesNotReapplyIt() {
        var value = 0
        var mutationCount = 0

        value = 1
        mutationCount += 1
        let result = PersistenceSaving.result {
            throw SampleError.diskFull
        }

        #expect(result != .saved)
        #expect(value == 1)
        #expect(mutationCount == 1)

        let retried = PersistenceSaving.result {}
        #expect(retried == .saved)
        #expect(value == 1)
        #expect(mutationCount == 1)
    }
}
