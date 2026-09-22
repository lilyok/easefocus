import Foundation

nonisolated struct QuoteMemory: Equatable, Sendable {
    static let capacity = 5
    static let defaultsKey = "easefocus.recentQuotes.v1"

    var recent: [String]

    init(recent: [String] = []) {
        self.recent = Array(recent.suffix(Self.capacity))
    }

    var lastShown: String? {
        recent.last
    }

    func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func contains(_ quote: String) -> Bool {
        let needle = normalized(quote)
        guard !needle.isEmpty else {
            return false
        }
        return recent.contains { normalized($0) == needle }
    }

    func isSameAsLast(_ quote: String) -> Bool {
        guard let lastShown else {
            return false
        }
        return normalized(lastShown) == normalized(quote)
    }

    func remembered(_ quote: String) -> QuoteMemory {
        let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return self
        }
        var next = recent.filter { normalized($0) != normalized(trimmed) }
        next.append(trimmed)
        if next.count > Self.capacity {
            next.removeFirst(next.count - Self.capacity)
        }
        return QuoteMemory(recent: next)
    }

    static func load(from defaults: UserDefaults = .standard) -> QuoteMemory {
        guard let data = defaults.data(forKey: defaultsKey),
              let recent = try? JSONDecoder().decode([String].self, from: data)
        else {
            return QuoteMemory()
        }
        return QuoteMemory(recent: recent)
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(recent) else {
            return
        }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}

nonisolated struct LocalQuote: Equatable, Sendable {
    var text: String
    var author: String

    var memoryKey: String {
        "\(text) — \(author)"
    }
}

nonisolated enum LocalQuotes {
    static let all: [LocalQuote] = [
        LocalQuote(text: "Well begun is half done.", author: "Aristotle"),
        LocalQuote(text: "The journey of a thousand miles begins with a single step.", author: "Lao Tzu"),
        LocalQuote(text: "It is not because things are difficult that we do not dare; it is because we do not dare that they are difficult.", author: "Seneca"),
        LocalQuote(text: "You have power over your mind — not outside events. Realize this, and you will find strength.", author: "Marcus Aurelius"),
        LocalQuote(text: "It does not matter how slowly you go as long as you do not stop.", author: "Confucius"),
        LocalQuote(text: "What you do speaks so loudly that I cannot hear what you say.", author: "Ralph Waldo Emerson"),
        LocalQuote(text: "Energy and persistence conquer all things.", author: "Benjamin Franklin"),
        LocalQuote(text: "Whatever you can do, or dream you can, begin it.", author: "Johann Wolfgang von Goethe"),
        LocalQuote(text: "The secret of getting ahead is getting started.", author: "Mark Twain"),
        LocalQuote(text: "Do what you can, with what you have, where you are.", author: "Theodore Roosevelt"),
        LocalQuote(text: "We are what we repeatedly do. Excellence, then, is not an act, but a habit.", author: "Aristotle"),
        LocalQuote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
        LocalQuote(text: "Focus is a matter of deciding what things you're not going to do.", author: "John Carmack"),
        LocalQuote(text: "Productivity is never an accident. It is always the result of a commitment to excellence.", author: "Paul J. Meyer"),
        LocalQuote(text: "Action is the foundational key to all success.", author: "Pablo Picasso"),
    ]
}

nonisolated enum QuoteSelecting {
    static func candidates(
        from library: [LocalQuote] = LocalQuotes.all,
        memory: QuoteMemory
    ) -> [LocalQuote] {
        let unused = library.filter {
            !memory.contains($0.memoryKey) && !memory.isSameAsLast($0.memoryKey)
        }
        if !unused.isEmpty {
            return unused
        }
        let notLast = library.filter { !memory.isSameAsLast($0.memoryKey) }
        return notLast.isEmpty ? library : notLast
    }

    static func hardcoded(from library: [LocalQuote] = LocalQuotes.all, memory: QuoteMemory) -> LocalQuote {
        candidates(from: library, memory: memory).first
            ?? library.first
            ?? LocalQuote(
                text: "Well begun is half done.",
                author: "Aristotle"
            )
    }

    static func quote(atOneBasedIndex index: Int, in candidates: [LocalQuote]) -> LocalQuote? {
        let zeroBased = index - 1
        guard candidates.indices.contains(zeroBased) else {
            return nil
        }
        return candidates[zeroBased]
    }

    static func acceptedGenerated(_ quote: String, memory: QuoteMemory) -> String? {
        let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        guard !memory.isSameAsLast(trimmed) else {
            return nil
        }
        return trimmed
    }

    static func titlesForQuote(plans: [GoalPlan]) -> [String] {
        let active = plans.filter { $0.status == .active }
        var titles: [String] = []
        for plan in active {
            titles.append(plan.title)
            titles.append(contentsOf: plan.orderedTasks.map(\.title))
        }
        return titles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
