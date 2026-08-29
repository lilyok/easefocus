import SwiftData
import SwiftUI

struct SessionHistoryView: View {
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var sessions: [FocusSession]

    private var completedToday: [FocusSession] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return sessions.filter { session in
            session.outcome == .completed && session.startedAt >= startOfDay
        }
    }

    private var brokenToday: [FocusSession] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return sessions.filter { session in
            session.outcome?.isBroken == true && session.startedAt >= startOfDay
        }
    }

    private var todayFocusSeconds: Int {
        completedToday.reduce(0) { $0 + $1.elapsedSeconds }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No sessions yet", systemImage: "chart.line.uptrend.xyaxis")
                    } description: {
                        Text("Completed and broken focus sessions will show up here.")
                    }
                } else {
                    List {
                        Section("Today") {
                            Text("\(completedToday.count) completed · \(brokenToday.count) broken · \(FocusDurationFormat.clock(todayFocusSeconds)) focused")
                                .font(FocusTypography.body)
                        }
                        Section("History") {
                            ForEach(sessions) { session in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.task?.title ?? "Quick focus")
                                        .font(FocusTypography.body)
                                    Text(sessionDetail(session))
                                        .font(FocusTypography.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.focusBackground)
            .navigationTitle("Progress")
        }
    }

    private func sessionDetail(_ session: FocusSession) -> String {
        let outcome = session.outcome?.progressTitle ?? "open"
        return "\(outcome) · \(FocusDurationFormat.clock(session.elapsedSeconds)) · \(session.startedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(try! EaseFocusStore.inMemoryContainer())
}
