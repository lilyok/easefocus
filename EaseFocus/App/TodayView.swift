import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusItem.createdAt, order: .reverse) private var items: [FocusItem]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("Ready to focus", systemImage: "timer")
                    } description: {
                        Text("EaseFocus is ready for your first goal.")
                    } actions: {
                        Button("Create a sample item", systemImage: "plus", action: addSampleItem)
                            .accessibilityIdentifier("createSampleItem")
                            .frame(minWidth: FocusSpacing.minimumTapTarget, minHeight: FocusSpacing.minimumTapTarget)
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            Text(item.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.focusBackground)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Create a sample item", systemImage: "plus", action: addSampleItem)
                }
            }
        }
    }

    private func addSampleItem() {
        modelContext.insert(FocusItem())
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: FocusItem.self, inMemory: true)
}
