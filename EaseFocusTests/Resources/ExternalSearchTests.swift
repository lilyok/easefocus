import Foundation
import Testing
@testable import EaseFocus

struct ExternalSearchTests {
    @Test
    func constructsAnHTTPSGoogleURLFromAValidatedQuery() throws {
        let url = try #require(GoogleSearchURL.make(from: "beginner English pronunciation exercises"))

        #expect(url.scheme == "https")
        #expect(url.host == "www.google.com")
        #expect(url.path == "/search")
        #expect(url.query?.contains("beginner") == true)
        #expect(url.absoluteString.contains("https://www.google.com/search?q=") )
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
    }

    @Test
    func privacyCopyDisclosesThatSearchLeavesTheApp() {
        #expect(ExternalSearchPrivacyCopy.body.contains("Nothing is sent until you tap Search Google"))
        #expect(ExternalSearchPrivacyCopy.body.contains("Google’s privacy terms"))
    }
}
