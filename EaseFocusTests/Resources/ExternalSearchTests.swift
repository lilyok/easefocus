import Foundation
import Testing
@testable import EaseFocus

@MainActor
final class RecordingExternalURLOpener: ExternalURLOpening, @unchecked Sendable {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) {
        openedURLs.append(url)
    }
}

struct ExternalSearchTests {
    @Test
    func constructsAnHTTPSGoogleURLFromAValidatedQuery() throws {
        let query = "beginner English pronunciation exercises"
        let url = try #require(GoogleSearchURL.make(from: query))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(url.scheme == "https")
        #expect(url.host == "www.google.com")
        #expect(url.path == "/search")
        #expect(components.queryItems?.map(\.name) == ["q"])
        #expect(components.queryItems?.first?.value == query)
        #expect(url.absoluteString.hasPrefix("https://www.google.com/search?q="))
    }

    @Test
    func rejectsEmptyQueries() {
        #expect(SearchQueryValidator.validate("   ") == .failure(.empty))
        #expect(SearchQueryValidator.validateOptional("   ") == .success(nil))
        #expect(GoogleSearchURL.make(from: "   ") == nil)
    }

    @Test
    func rejectsURLLikeQueries() {
        #expect(SearchQueryValidator.validate("https://example.com") == .failure(.urlLikeContent))
        #expect(SearchQueryValidator.validate("www.example.com drills") == .failure(.urlLikeContent))
        #expect(GoogleSearchURL.make(from: "http://evil.example") == nil)
        #expect(GoogleSearchURL.make(from: "https://www.google.com/search?q=secret") == nil)
    }

    @Test
    func acceptsAndTrimsAnOptionalQuery() {
        #expect(
            SearchQueryValidator.validateOptional("  Spanish pronunciation  ")
                == .success("Spanish pronunciation")
        )
    }

    @Test
    func rejectsOverlongQueries() {
        let query = String(repeating: "a", count: SearchQueryValidator.maximumLength + 1)

        #expect(SearchQueryValidator.validate(query) == .failure(.tooLong))
        #expect(SearchQueryValidator.validateOptional(query) == .failure(.tooLong))
        #expect(GoogleSearchURL.make(from: query) == nil)
    }

    @Test
    func privacyCopyDisclosesThatSearchLeavesTheApp() {
        #expect(ExternalSearchPrivacyCopy.body.contains("Nothing is sent until you tap Search Google"))
        #expect(ExternalSearchPrivacyCopy.body.contains("Google’s privacy terms"))
        #expect(ExternalSearchPrivacyCopy.body.contains("health, legal, financial, or safety-sensitive"))
        #expect(
            ExternalSearchPrivacyCopy.confirmationMessage(for: "Spanish greetings audio")
                .contains("Spanish greetings audio")
        )
    }

    @Test
    @MainActor
    func requestingSearchDoesNotOpenAURL() {
        let opener = RecordingExternalURLOpener()
        let request = ExternalSearchOpening.request(from: "beginner English pronunciation exercises")

        #expect(request?.query == "beginner English pronunciation exercises")
        #expect(opener.openedURLs.isEmpty)
    }

    @Test
    @MainActor
    func confirmationOpensTheExactEncodedGoogleURL() throws {
        let opener = RecordingExternalURLOpener()
        let query = "beginner English pronunciation exercises"
        let expected = try #require(GoogleSearchURL.make(from: query))

        let opened = ExternalSearchOpening.confirm(query: query, opener: opener)

        #expect(opened == expected)
        #expect(opener.openedURLs == [expected])
        let components = try #require(URLComponents(url: expected, resolvingAgainstBaseURL: false))
        #expect(components.queryItems == [URLQueryItem(name: "q", value: query)])
    }

    @Test
    @MainActor
    func confirmationRevalidatesAndDoesNotOpenInvalidQueries() {
        let opener = RecordingExternalURLOpener()

        #expect(ExternalSearchOpening.request(from: "   ") == nil)
        #expect(ExternalSearchOpening.request(from: "https://example.com") == nil)
        #expect(
            ExternalSearchOpening.request(
                from: String(repeating: "a", count: SearchQueryValidator.maximumLength + 1)
            ) == nil
        )
        #expect(ExternalSearchOpening.confirm(query: "   ", opener: opener) == nil)
        #expect(ExternalSearchOpening.confirm(query: "www.example.com", opener: opener) == nil)
        #expect(
            ExternalSearchOpening.confirm(
                query: String(repeating: "a", count: SearchQueryValidator.maximumLength + 1),
                opener: opener
            ) == nil
        )
        #expect(opener.openedURLs.isEmpty)
    }
}
