import Foundation

nonisolated enum MotivationalQuotePrompt {
    static let maxTitles = 8
    static let maxTitleLength = 40

    static func instructions(locale: Locale) -> String {
        """
        You choose one real motivational quote from a numbered list.
        Output language preference: \(locale.identifier).
        Never invent a quote or author. Never rewrite the quote text.
        Reply only by selecting the index of an existing list entry.
        Prefer a quote that fits the user's current tasks and goals.
        Avoid recently shown quotes when possible.
        """
    }

    static func userMessage(
        taskTitles: [String],
        candidates: [LocalQuote]
    ) -> String {
        let titles = truncatedTitles(taskTitles)
        let titleBlock = titles.isEmpty
            ? "none"
            : titles.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let quoteBlock = candidates.enumerated().map { index, quote in
            "\(index + 1). \"\(quote.text)\" — \(quote.author)"
        }.joined(separator: "\n")

        return """
        Task and goal titles (theme only):
        \(titleBlock)

        Choose exactly one quote from this numbered list of real attributed quotes:
        \(quoteBlock)

        Return the 1-based index of the best matching quote. Do not invent text.
        """
    }

    static func truncatedTitles(_ titles: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for title in titles {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }
            let clipped = String(trimmed.prefix(maxTitleLength))
            let key = clipped.lowercased()
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            result.append(clipped)
            if result.count == maxTitles {
                break
            }
        }
        return result
    }
}
