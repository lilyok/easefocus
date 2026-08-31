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
        let message = PersistenceSaving.result {
            throw SampleError.diskFull
        }

        #expect(message?.contains("could not save") == true)
        #expect(message?.contains("The disk is full.") == true)
        #expect(PersistenceSaveCopy.title.contains("Couldn't save"))
    }

    @Test
    func clearsTheMessageWhenASaveSucceeds() {
        #expect(PersistenceSaving.result {} == nil)
    }
}
