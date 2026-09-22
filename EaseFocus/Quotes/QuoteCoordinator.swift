import Foundation

nonisolated enum QuoteCoordinator {
    /// Picks a real attributed quote from the curated library.
    /// Apple Intelligence may rank candidates using task titles; it never invents quote text.
    static func nextQuote(
        taskTitles: [String],
        memory: QuoteMemory,
        client: any FoundationModelGenerating,
        locale: Locale,
        library: [LocalQuote] = LocalQuotes.all
    ) async -> (quote: LocalQuote, memory: QuoteMemory) {
        let candidates = QuoteSelecting.candidates(from: library, memory: memory)
        let quote: LocalQuote
        if client.currentAvailability(locale: locale).allowsGeneration,
           candidates.count > 1 {
            do {
                quote = try await client.selectMotivationalQuote(
                    taskTitles: taskTitles,
                    candidates: candidates,
                    locale: locale
                )
            } catch {
                quote = QuoteSelecting.hardcoded(from: library, memory: memory)
            }
        } else {
            quote = QuoteSelecting.hardcoded(from: library, memory: memory)
        }
        return (quote, memory.remembered(quote.memoryKey))
    }
}
