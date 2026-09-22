import Foundation

nonisolated struct RemoteQuotePayload: Codable, Equatable, Sendable {
    var text: String
    var author: String
}

nonisolated enum QuoteCatalogParsing {
    static func quotes(from data: Data) throws -> [LocalQuote] {
        let decoder = JSONDecoder()
        let payloads = try decoder.decode([RemoteQuotePayload].self, from: data)
        return payloads.compactMap { payload in
            let text = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let author = payload.author.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !author.isEmpty else {
                return nil
            }
            return LocalQuote(text: text, author: author)
        }
    }

    static func encode(_ quotes: [LocalQuote]) throws -> Data {
        let payloads = quotes.map {
            RemoteQuotePayload(text: $0.text, author: $0.author)
        }
        return try JSONEncoder().encode(payloads)
    }
}

nonisolated enum QuoteMerging {
    /// Keeps every bundled quote and appends remote ones that are not already present.
    /// Match key is normalized quote text (author-only differences do not duplicate).
    static func merge(base: [LocalQuote], remote: [LocalQuote]) -> [LocalQuote] {
        var seen = Set(base.map { normalizedText($0.text) })
        var merged = base
        for quote in remote {
            let key = normalizedText(quote.text)
            guard !key.isEmpty, !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            merged.append(quote)
        }
        return merged
    }

    static func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
