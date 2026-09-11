import SwiftUI

/// Shared empty state: EaseFocusMark + title + description + optional primary actions.
struct FocusEmptyState<Actions: View>: View {
    let title: LocalizedCopy
    let description: LocalizedCopy
    var markSize: CGFloat = 64
    @ViewBuilder var actions: () -> Actions

    init(
        title: LocalizedCopy,
        description: LocalizedCopy,
        markSize: CGFloat = 64,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.description = description
        self.markSize = markSize
        self.actions = actions
    }

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: FocusSpacing.medium) {
                EaseFocusMark(size: markSize)
                Text(title)
                    .font(FocusTypography.title)
                    .foregroundStyle(Color.focusPrimary)
            }
        } description: {
            Text(description)
        } actions: {
            actions()
        }
    }
}

extension FocusEmptyState where Actions == EmptyView {
    init(
        title: LocalizedCopy,
        description: LocalizedCopy,
        markSize: CGFloat = 64
    ) {
        self.init(title: title, description: description, markSize: markSize) {
            EmptyView()
        }
    }
}

#Preview {
    FocusEmptyState(
        title: TodayCopy.readyToFocus,
        description: TodayCopy.emptyDescription
    ) {
        Button(TodayCopy.createPlan, systemImage: "plus") {}
            .focusPrimaryActionStyle()
    }
    .background(Color.focusBackground)
}
