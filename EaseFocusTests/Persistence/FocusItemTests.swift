import Foundation
import Testing
@testable import EaseFocus

struct FocusItemTests {
    @Test
    @MainActor
    func storesItsCreationDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let item = FocusItem(createdAt: date)

        #expect(item.createdAt == date)
    }
}
