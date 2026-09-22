import Foundation
import Testing
@testable import EaseFocus

struct QuoteCatalogParsingTests {
    @Test
    func parsesValidQuotesAndDropsEmptyRows() throws {
        let json = """
        [
          {"text":"Hello","author":"Ada"},
          {"text":"  ","author":"Ada"},
          {"text":"World","author":"  "},
          {"text":" Focus ","author":" Grace "}
        ]
        """.data(using: .utf8)!
        let quotes = try QuoteCatalogParsing.quotes(from: json)
        #expect(quotes == [
            LocalQuote(text: "Hello", author: "Ada"),
            LocalQuote(text: "Focus", author: "Grace"),
        ])
    }

    @Test
    func mergeAppendsOnlyNewQuotesByText() {
        let base = [
            LocalQuote(text: "Well begun is half done.", author: "Aristotle"),
        ]
        let remote = [
            LocalQuote(text: "Well begun is half done.", author: "Someone Else"),
            LocalQuote(text: "You miss 100 percent of the shots you don't take.", author: "Wayne Gretzky"),
        ]
        let merged = QuoteMerging.merge(base: base, remote: remote)
        #expect(merged.count == 2)
        #expect(merged[0].author == "Aristotle")
        #expect(merged[1].author == "Wayne Gretzky")
    }

    @Test
    func mergeKeepsBundledQuotesWhenRemoteIsEmpty() {
        let merged = QuoteMerging.merge(base: LocalQuotes.all, remote: [])
        #expect(merged == LocalQuotes.all)
    }
}
