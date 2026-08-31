import Foundation

nonisolated enum TaskMoveDirection: Sendable {
    case up
    case down
}

nonisolated enum TaskOrdering {
    static func reordered<Element: Identifiable>(
        _ items: [Element],
        moving id: Element.ID,
        direction: TaskMoveDirection
    ) -> [Element] where Element.ID: Equatable {
        guard let source = items.firstIndex(where: { $0.id == id }) else {
            return items
        }

        let destination: Int
        switch direction {
        case .up:
            destination = source - 1
        case .down:
            destination = source + 1
        }
        guard items.indices.contains(destination) else {
            return items
        }

        var result = items
        result.swapAt(source, destination)
        return result
    }
}
