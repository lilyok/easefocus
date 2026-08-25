import Foundation
import SwiftData

@Model
final class FocusItem {
    var createdAt: Date

    init(createdAt: Date = .now) {
        self.createdAt = createdAt
    }
}
