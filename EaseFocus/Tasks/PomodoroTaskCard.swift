import SwiftUI

struct PomodoroTaskCard: View {
    let task: PlanTask
    var canStart: Bool
    var showsActions: Bool = true
    var isPinnedActive: Bool = false
    var sessionStatus: LocalizedCopy?
    var remainingSeconds: Int?
    var plannedDurationSeconds: Int?
    var timerActions: [CompactTimerAction] = []
    var onTimerAction: (CompactTimerAction) -> Void = { _ in }
    var onStart: () -> Void = {}
    var onComplete: () -> Void = {}
    var onTitleCommit: (String) -> Void = { _ in }
    var isCelebrating: Bool = false
    var isNewlyCreated: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @FocusState private var isTitleFocused: Bool
    @State private var draftTitle = ""

    private var isCompleted: Bool {
        task.status == .completed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.medium) {
            if isPinnedActive {
                pinnedTimer
            }
            if let planTitle = task.plan?.title, !planTitle.isEmpty {
                PlanNameLabel(title: planTitle)
            }
            HStack(alignment: .top, spacing: FocusSpacing.medium) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PomodoroCopy.taskName)
                        .font(FocusTypography.footnote)
                        .foregroundStyle(.secondary)
                    TextField(PomodoroCopy.taskName, text: $draftTitle, axis: .vertical)
                        .font(FocusTypography.title)
                        .foregroundStyle(Color.focusPrimary)
                        .focusField()
                        .focused($isTitleFocused)
                        .textFieldStyle(.plain)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("taskTitleField")
                        .onSubmit {
                            commitTitle()
                            isTitleFocused = false
                        }
                }
                Spacer(minLength: FocusSpacing.small)
                pomodoroCount(value: task.completedSessionCount, caption: PomodoroCopy.completedPomodoros)
                pomodoroCount(value: task.brokenSessionCount, caption: PomodoroCopy.spoiledPomodoros)
            }

            if isPinnedActive, !timerActions.isEmpty {
                ForEach(timerActions) { action in
                    TimerPhaseControlButton(action: action, usesCompactTitle: false) {
                        onTimerAction(action)
                    }
                }
                if !isCompleted {
                    cardAction(
                        PomodoroCopy.complete,
                        enabled: true,
                        fill: Color.focusError,
                        action: onComplete
                    )
                } else {
                    cardAction(
                        PomodoroCopy.undoComplete,
                        enabled: true,
                        fill: Color.focusAccent,
                        action: onComplete
                    )
                }
            } else if showsActions {
                if isCompleted {
                    VStack(spacing: FocusSpacing.small) {
                        Text(PomodoroCopy.completedBadge)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.focusError)
                            .frame(maxWidth: .infinity)
                        cardAction(
                            PomodoroCopy.undoComplete,
                            enabled: true,
                            fill: Color.focusAccent,
                            action: onComplete
                        )
                    }
                } else {
                    HStack(spacing: FocusSpacing.small) {
                        cardAction(
                            TaskCopy.start,
                            enabled: canStart,
                            fill: Color.focusAccent,
                            action: onStart
                        )
                        cardAction(
                            PomodoroCopy.complete,
                            enabled: true,
                            fill: Color.focusError,
                            action: onComplete
                        )
                    }
                }
            }
        }
        .padding(FocusSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(highlightStroke, lineWidth: highlightLineWidth)
        }
        .overlay {
            if isCelebrating {
                TaskCompletionBurst()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .scaleEffect(isNewlyCreated && !reduceMotion ? 1.03 : 1)
        .shadow(
            color: Color.focusAccent.opacity(isNewlyCreated && !reduceMotion ? 0.35 : 0),
            radius: isNewlyCreated && !reduceMotion ? 16 : 0
        )
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isCompleted)
        .animation(.easeOut(duration: 0.2), value: isCelebrating)
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: isNewlyCreated)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isPinnedActive ? "pinnedActiveTask" : "")
        .onAppear {
            draftTitle = task.title
            if isNewlyCreated {
                isTitleFocused = true
            }
        }
        .onChange(of: task.id) { _, _ in
            draftTitle = task.title
        }
        .onChange(of: task.title) { _, newTitle in
            if !isTitleFocused {
                draftTitle = newTitle
            }
        }
        .onChange(of: isTitleFocused) { _, focused in
            if !focused {
                commitTitle()
            }
        }
        .onChange(of: isNewlyCreated) { _, created in
            if created {
                isTitleFocused = true
            }
        }
    }

    private func commitTitle() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = trimmed.isEmpty ? TaskCopy.newTask.localized(locale) : trimmed
        draftTitle = next
        guard next != task.title else {
            return
        }
        onTitleCommit(next)
    }

    private var cardFill: Color {
        if isNewlyCreated {
            return Color.focusAccent.opacity(0.2)
        }
        return isPinnedActive ? Color.focusAccent.opacity(0.14) : Color.focusSurface
    }

    private var highlightStroke: AnyShapeStyle {
        if isNewlyCreated {
            return AnyShapeStyle(FocusChrome.gradient(for: .accent))
        }
        if isPinnedActive {
            return AnyShapeStyle(Color.focusAccent)
        }
        return AnyShapeStyle(Color.clear)
    }

    private var highlightLineWidth: CGFloat {
        if isNewlyCreated {
            return 3
        }
        return isPinnedActive ? 2 : 0
    }

    @ViewBuilder
    private var pinnedTimer: some View {
        VStack(spacing: FocusSpacing.small) {
            Text(sessionStatus ?? PomodoroCopy.nowFocusing)
                .font(FocusTypography.footnote.weight(.semibold))
                .foregroundStyle(FocusChrome.accentEnd)
            if let remainingSeconds {
                ZStack {
                    FocusTimerProgressRing(progress: timerProgress, lineWidth: 6)
                    Text(FocusDurationFormat.clock(remainingSeconds))
                        .font(FocusTypography.timerFitted)
                        .monospacedDigit()
                        .foregroundStyle(FocusChrome.gradient(for: .accent))
                }
                .frame(width: 128, height: 128)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(TimerAccessibilityCopy.remainingTime)
                .accessibilityValue("\(remainingSeconds)")
                .accessibilityIdentifier(TimerAccessibilityIdentifier.timerRemainingTime)
            }
        }
        .padding(.vertical, FocusSpacing.small)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.focusBackground.opacity(0.7))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FocusChrome.gradient(for: .accent), lineWidth: 2)
        }
    }

    private var timerProgress: CGFloat {
        guard let remainingSeconds, let plannedDurationSeconds, plannedDurationSeconds > 0 else {
            return 0
        }
        let elapsed = max(0, plannedDurationSeconds - remainingSeconds)
        return CGFloat(elapsed) / CGFloat(plannedDurationSeconds)
    }

    private func pomodoroCount(value: Int, caption: LocalizedCopy) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(FocusTypography.title)
                .foregroundStyle(Color.focusPrimary)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(caption.english)")
    }

    private func cardAction(
        _ title: LocalizedCopy,
        enabled: Bool,
        fill: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .focusCapsuleFill(fill, enabled: enabled)
        }
        .buttonStyle(FocusCapsuleButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}
