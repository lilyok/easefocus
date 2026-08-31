import SwiftUI

struct TaskResourceSearchControls: View {
    let taskID: UUID
    var state: ResourceSearchControlState
    @Binding var query: String
    var onAdd: () -> Void
    var onRemove: () -> Void
    var onSearch: (String) -> Void

    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .addAction:
            Button(ResourceSearchSuggestionCopy.addAction, action: onAdd)
                .font(FocusTypography.footnote)
                .accessibilityIdentifier("addResourceSearch-\(taskID)")
        case .editor:
            VStack(alignment: .leading, spacing: FocusSpacing.small) {
                TaskSearchQueryFields(
                    taskID: taskID,
                    query: $query,
                    onSearch: onSearch
                )
                Button(ResourceSearchSuggestionCopy.removeAction, action: onRemove)
                    .font(FocusTypography.footnote)
                    .accessibilityIdentifier("removeResourceSearch-\(taskID)")
            }
        }
    }
}
