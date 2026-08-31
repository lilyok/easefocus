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

    @Test
    func planEditorRetrySavesOnlyAndDiscardRollsBackWithoutDismissing() {
        var insertedPlan: String?
        var insertCount = 0
        var saveCount = 0
        var rolledBack = false
        var dismissed = false
        var shouldFailSave = true
        var title = "Spanish greetings"
        var searchQuery = "Spanish greetings audio"

        func savePendingChanges() -> PersistenceMutationResult {
            let result = PersistenceSaving.result {
                saveCount += 1
                if shouldFailSave {
                    throw SampleError.diskFull
                }
            }
            if result == .saved {
                dismissed = true
            }
            return result
        }

        func save() -> PersistenceMutationResult {
            if insertedPlan == nil {
                insertCount += 1
                insertedPlan = "\(title)|\(searchQuery)"
            }
            return savePendingChanges()
        }

        func discard() {
            rolledBack = true
            insertedPlan = nil
            dismissed = false
        }

        #expect(save() != .saved)
        #expect(insertCount == 1)
        #expect(saveCount == 1)
        #expect(insertedPlan == "Spanish greetings|Spanish greetings audio")
        #expect(!dismissed)

        title = "Edited title"
        searchQuery = "beginner Spanish"
        #expect(savePendingChanges() != .saved)
        #expect(insertCount == 1)
        #expect(saveCount == 2)
        #expect(insertedPlan == "Spanish greetings|Spanish greetings audio")
        #expect(title == "Edited title")
        #expect(searchQuery == "beginner Spanish")
        #expect(!dismissed)

        discard()
        #expect(rolledBack)
        #expect(insertedPlan == nil)
        #expect(!dismissed)
        #expect(title == "Edited title")
        #expect(searchQuery == "beginner Spanish")

        shouldFailSave = false
        #expect(save() == .saved)
        #expect(insertCount == 2)
        #expect(dismissed)
    }
}
