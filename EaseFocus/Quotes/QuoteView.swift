import SwiftData
import SwiftUI

struct QuoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.foundationModelClient) private var foundationModelClient
    @Query(sort: \GoalPlan.updatedAt, order: .reverse) private var plans: [GoalPlan]

    @State private var quote: LocalQuote?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: FocusSpacing.large) {
            Text(QuoteCopy.motivationalQuoteForYou)
                .font(FocusTypography.footnote)
                .foregroundStyle(.secondary)
            if isLoading && quote == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let quote {
                VStack(spacing: FocusSpacing.medium) {
                    Text(quote.text)
                        .font(FocusTypography.title)
                        .foregroundStyle(Color.focusPrimary)
                        .multilineTextAlignment(.center)
                    Text("— \(quote.author)")
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focusCard()
            }
            FocusCapsuleButton(title: QuoteCopy.gotIt, identifier: "dismissQuote") {
                dismiss()
            }
        }
        .padding(FocusSpacing.large)
        .focusScreen()
        .task {
            await loadQuote()
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }

    private func loadQuote() async {
        isLoading = true
        let memory = QuoteMemory.load()
        let titles = QuoteSelecting.titlesForQuote(plans: plans)
        let result = await QuoteCoordinator.nextQuote(
            taskTitles: titles,
            memory: memory,
            client: foundationModelClient,
            locale: locale,
            library: QuoteLibraryStore.library
        )
        result.memory.save()
        quote = result.quote
        isLoading = false
    }
}

#Preview {
    QuoteView()
        .environment(\.foundationModelClient, PreviewFoundationModelClient())
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
