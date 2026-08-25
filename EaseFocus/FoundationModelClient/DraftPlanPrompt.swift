import Foundation

nonisolated enum DraftPlanPrompt {
    static func instructions(locale: Locale) -> String {
        """
        You create short, concrete focus plans.
        Output in \(locale.identifier).
        Do not include URLs, domain names, or citations.
        Do not claim you searched the web.
        Tasks must be achievable and specific.
        """
    }
}
