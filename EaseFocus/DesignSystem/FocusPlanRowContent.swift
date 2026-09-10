import SwiftUI

/// Shared plan title + open/done line used by Plans and Progress.
struct FocusPlanRowContent: View {
    @Environment(\.locale) private var locale

    let title: String
    let openCount: Int
    let doneCount: Int
    var showsCompletedBadge: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: FocusSpacing.small) {
                Text(title)
                    .font(FocusTypography.body)
                    .foregroundStyle(Color.focusPrimary)
                if showsCompletedBadge {
                    Text(ProgressCopy.completedPlan)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Text(ProgressPresentation.planTaskLine(open: openCount, done: doneCount, locale: locale))
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    FocusPlanRowContent(title: "Learn Spanish", openCount: 3, doneCount: 2)
        .padding()
        .background(Color.focusBackground)
}
