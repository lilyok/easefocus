import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

nonisolated enum SearchQueryValidationError: Equatable, Error {
    case empty
    case tooLong
    case urlLikeContent
}

nonisolated enum SearchQueryValidator {
    static let maximumLength = 120

    static func validate(_ query: String) -> Result<String, SearchQueryValidationError> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.empty)
        }
        guard trimmed.count <= maximumLength else {
            return .failure(.tooLong)
        }

        let lowered = trimmed.lowercased()
        if lowered.contains("http://") || lowered.contains("https://") || lowered.contains("www.") {
            return .failure(.urlLikeContent)
        }

        return .success(trimmed)
    }

    static func validateOptional(
        _ query: String
    ) -> Result<String?, SearchQueryValidationError> {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .success(nil)
        }
        return validate(query).map(Optional.some)
    }
}

nonisolated enum SearchQueryValidationCopy {
    static func message(for error: SearchQueryValidationError) -> String {
        switch error {
        case .empty:
            return "Leave this field blank to remove the search query."
        case .tooLong:
            return "Keep the search query to \(SearchQueryValidator.maximumLength) characters or fewer."
        case .urlLikeContent:
            return "Enter search terms, not a URL or website address."
        }
    }
}

nonisolated enum GoogleSearchURL {
    static func make(from query: String) -> URL? {
        guard case .success(let validated) = SearchQueryValidator.validate(query) else {
            return nil
        }

        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: validated)
        ]
        return components?.url
    }
}

nonisolated enum ExternalSearchPrivacyCopy {
    static let title = "Search happens in your browser"
    static let confirmationTitle = "Search Google?"
    static let confirmAction = "Search Google"
    static let cancelAction = "Cancel"

    static let body = """
    EaseFocus can suggest a search query for a task. Nothing is sent until you tap Search Google.

    The query leaves EaseFocus and is handled under Google’s privacy terms. Generated plans, survey answers, and focus history stay on this device.

    EaseFocus does not inspect, save, or endorse the results. For health, legal, financial, or safety-sensitive goals, treat results as starting points only.
    """

    static func confirmationMessage(for query: String) -> String {
        """
        Search Google for “\(query)”.

        \(body)
        """
    }
}

nonisolated protocol ExternalURLOpening: Sendable {
    @MainActor
    func open(_ url: URL)
}

struct SystemExternalURLOpener: ExternalURLOpening {
    @MainActor
    func open(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

struct ExternalSearchRequest: Identifiable, Hashable, Sendable {
    let query: String
    var id: String { query }
}

nonisolated enum ExternalSearchOpening {
    static func request(from query: String) -> ExternalSearchRequest? {
        guard case .success(let validated) = SearchQueryValidator.validate(query) else {
            return nil
        }
        return ExternalSearchRequest(query: validated)
    }

    @MainActor
    @discardableResult
    static func confirm(
        query: String,
        opener: any ExternalURLOpening
    ) -> URL? {
        guard let url = GoogleSearchURL.make(from: query) else {
            return nil
        }
        opener.open(url)
        return url
    }
}
