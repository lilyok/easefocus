import Foundation
import Testing
@testable import EaseFocus

struct QuoteSelectingTests {
    @Test
    func hardcodedSkipsRecentQuotesAndTheLastShownQuote() {
        let first = LocalQuotes.all[0]
        let second = LocalQuotes.all[1]
        let memory = QuoteMemory(recent: [first.memoryKey, second.memoryKey])
        let quote = QuoteSelecting.hardcoded(memory: memory)
        #expect(quote == LocalQuotes.all[2])
        #expect(!memory.contains(quote.memoryKey))
        #expect(!memory.isSameAsLast(quote.memoryKey))
        #expect(quote.author == "Seneca")
    }

    @Test
    func rememberedKeepsOnlyTheLastFiveQuotes() {
        var memory = QuoteMemory()
        for index in 1...6 {
            memory = memory.remembered("Quote \(index)")
        }
        #expect(memory.recent == ["Quote 2", "Quote 3", "Quote 4", "Quote 5", "Quote 6"])
        #expect(memory.lastShown == "Quote 6")
    }

    @Test
    func acceptedGeneratedRejectsEmptyAndLastShown() {
        let memory = QuoteMemory(recent: ["Keep going."])
        #expect(QuoteSelecting.acceptedGenerated("   ", memory: memory) == nil)
        #expect(QuoteSelecting.acceptedGenerated("Keep going.", memory: memory) == nil)
        #expect(QuoteSelecting.acceptedGenerated("A new line.", memory: memory) == "A new line.")
    }

    @Test
    func truncatedTitlesDedupesAndCapsLength() {
        let long = String(repeating: "a", count: 80)
        let titles = MotivationalQuotePrompt.truncatedTitles([
            " Practice Spanish ",
            "practice spanish",
            long,
            "Read",
        ])
        #expect(titles.count == 3)
        #expect(titles[0] == "Practice Spanish")
        #expect(titles[1].count == MotivationalQuotePrompt.maxTitleLength)
        #expect(titles[2] == "Read")
    }

    @Test
    func quoteAtOneBasedIndexMapsIntoCandidates() {
        let candidates = Array(LocalQuotes.all.prefix(3))
        #expect(QuoteSelecting.quote(atOneBasedIndex: 1, in: candidates) == candidates[0])
        #expect(QuoteSelecting.quote(atOneBasedIndex: 3, in: candidates) == candidates[2])
        #expect(QuoteSelecting.quote(atOneBasedIndex: 0, in: candidates) == nil)
        #expect(QuoteSelecting.quote(atOneBasedIndex: 4, in: candidates) == nil)
    }
}

struct QuoteCoordinatorTests {
    @Test
    func usesAFamousAuthorQuoteFromTheLocalLibrary() async {
        var client = PreviewFoundationModelClient()
        client.availability = .available
        let memory = QuoteMemory()
        let result = await QuoteCoordinator.nextQuote(
            taskTitles: ["Practice"],
            memory: memory,
            client: client,
            locale: L10n.english
        )
        #expect(result.quote == LocalQuotes.all[0])
        #expect(result.quote.author == "Aristotle")
        #expect(result.memory.recent == [LocalQuotes.all[0].memoryKey])
    }

    @Test
    func skipsRecentlyShownFamousQuotes() async {
        let client = PreviewFoundationModelClient()
        let first = LocalQuotes.all[0]
        let result = await QuoteCoordinator.nextQuote(
            taskTitles: ["Practice"],
            memory: QuoteMemory(recent: [first.memoryKey]),
            client: client,
            locale: L10n.english
        )
        #expect(result.quote == LocalQuotes.all[1])
    }

    @Test
    func stillPicksALibraryQuoteWhenThereAreNoTaskTitles() async {
        let client = PreviewFoundationModelClient()
        let result = await QuoteCoordinator.nextQuote(
            taskTitles: [],
            memory: QuoteMemory(),
            client: client,
            locale: L10n.english
        )
        #expect(result.quote == LocalQuotes.all[0])
    }
}
