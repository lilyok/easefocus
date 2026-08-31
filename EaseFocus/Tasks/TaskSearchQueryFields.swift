import SwiftUI

struct TaskSearchQueryFields: View {
    let taskID: UUID
    @Binding var query: String
    var showsSearchAction: Bool = true
    var onSearch: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            TextField("Optional search query", text: $query, axis: .vertical)
                .accessibilityIdentifier("searchQuery-\(taskID)")
            if let error = searchQueryError {
                Text(SearchQueryValidationCopy.message(for: error))
                    .font(FocusTypography.footnote)
                    .foregroundStyle(Color.focusError)
                    .accessibilityIdentifier("searchQueryError-\(taskID)")
            }
            if showsSearchAction, let validated = validatedQuery {
                Button("Search Google") {
                    onSearch?(validated)
                }
                .accessibilityIdentifier("searchGoogle-\(taskID)")
            }
        }
    }

    private var searchQueryError: SearchQueryValidationError? {
        guard case .failure(let error) = SearchQueryValidator.validateOptional(query) else {
            return nil
        }
        return error
    }

    private var validatedQuery: String? {
        guard case .success(let validated) = SearchQueryValidator.validateOptional(query) else {
            return nil
        }
        return validated
    }
}
