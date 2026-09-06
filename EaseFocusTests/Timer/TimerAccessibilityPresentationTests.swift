import Foundation
import Testing
@testable import EaseFocus

struct TimerAccessibilityPresentationTests {
    @Test
    func statusTitlesCoverEachPhase() {
        #expect(
            TimerAccessibilityPresentation.statusTitle(phase: .idle, isLongBreak: false)
                == TimerAccessibilityCopy.idle
        )
        #expect(
            TimerAccessibilityPresentation.statusTitle(phase: .runningFocus, isLongBreak: false)
                == TimerAccessibilityCopy.focus
        )
        #expect(
            TimerAccessibilityPresentation.statusTitle(phase: .pausedFocus, isLongBreak: false)
                == TimerAccessibilityCopy.focusPaused
        )
        #expect(
            TimerAccessibilityPresentation.statusTitle(phase: .runningBreak, isLongBreak: false)
                == TimerAccessibilityCopy.breakStatus
        )
        #expect(
            TimerAccessibilityPresentation.statusTitle(phase: .runningBreak, isLongBreak: true)
                == TimerAccessibilityCopy.longBreak
        )
        #expect(
            TimerAccessibilityPresentation.statusTitle(phase: .pausedBreak, isLongBreak: true)
                == TimerAccessibilityCopy.breakPaused
        )
        #expect(
            TimerAccessibilityPresentation.statusTitle(phase: .completed, isLongBreak: false)
                == TimerAccessibilityCopy.focusComplete
        )
    }

    @Test
    func spokenRemainingUsesFullUnitsInsteadOfClockString() {
        #expect(TimerAccessibilityPresentation.spokenRemaining(seconds: 724) == "12 minutes 4 seconds remaining")
        #expect(TimerAccessibilityPresentation.spokenRemaining(seconds: 724) != FocusDurationFormat.clock(724))
        #expect(TimerAccessibilityPresentation.spokenRemaining(seconds: 1500) == "25 minutes remaining")
        #expect(TimerAccessibilityPresentation.spokenRemaining(seconds: 61) == "1 minute 1 second remaining")
        #expect(TimerAccessibilityPresentation.spokenRemaining(seconds: 60) == "1 minute remaining")
        #expect(TimerAccessibilityPresentation.spokenRemaining(seconds: 5) == "5 seconds remaining")
        #expect(TimerAccessibilityPresentation.spokenRemaining(seconds: 1) == "1 second remaining")
        #expect(TimerAccessibilityPresentation.spokenRemaining(seconds: 0) == "0 seconds remaining")
        #expect(TimerAccessibilityPresentation.spokenRemaining(seconds: -12) == "0 seconds remaining")
        #expect(TimerAccessibilityPresentation.spokenRemaining(seconds: 3600) == "1 hour remaining")
        #expect(TimerAccessibilityPresentation.spokenRemaining(seconds: 3661) == "1 hour 1 minute 1 second remaining")
    }

    @Test
    func runningFocusOffersPauseAndCancel() {
        #expect(
            TimerAccessibilityPresentation.actions(for: .runningFocus)
                == [.pause, .cancel]
        )
    }

    @Test
    func pausedFocusOffersResumeAndCancel() {
        #expect(
            TimerAccessibilityPresentation.actions(for: .pausedFocus)
                == [.resume, .cancel]
        )
    }

    @Test
    func runningBreakOffersPauseAndCancel() {
        #expect(
            TimerAccessibilityPresentation.actions(for: .runningBreak)
                == [.pause, .cancel]
        )
    }

    @Test
    func completedOffersBreakAndSkip() {
        #expect(
            TimerAccessibilityPresentation.actions(for: .completed)
                == [.startBreak, .skipBreak]
        )
        #expect(CompactTimerAction.startBreak.compactTitle == "Break")
        #expect(CompactTimerAction.skipBreak.compactTitle == "Skip")
        #expect(CompactTimerAction.startBreak.accessibilityLabel == "Start break")
        #expect(CompactTimerAction.skipBreak.accessibilityLabel == "Skip break")
    }

    @Test
    func idleOffersNoCompactActions() {
        #expect(TimerAccessibilityPresentation.actions(for: .idle).isEmpty)
        #expect(TimerAccessibilityPresentation.actions(for: .pausedBreak) == [.resume, .cancel])
    }

    @Test
    func reduceMotionDoesNotChangeAvailableActions() {
        let phases: [FocusTimerPhase] = [
            .idle,
            .runningFocus,
            .pausedFocus,
            .runningBreak,
            .pausedBreak,
            .completed,
        ]
        for phase in phases {
            #expect(
                TimerAccessibilityPresentation.actions(for: phase, reduceMotion: false)
                    == TimerAccessibilityPresentation.actions(for: phase, reduceMotion: true)
            )
        }
    }

    @Test
    func exposesTimerAccessibilityIdentifiers() {
        #expect(TimerAccessibilityIdentifier.compactTimer == "compactTimer")
        #expect(TimerAccessibilityIdentifier.openTimer == "openTimer")
        #expect(TimerAccessibilityIdentifier.remainingTime == "remainingTime")
        #expect(TimerAccessibilityIdentifier.timerRemainingTime == "timerRemainingTime")
        #expect(
            TimerAccessibilityIdentifier.remainingTime
                != TimerAccessibilityIdentifier.timerRemainingTime
        )
        #expect(TimerAccessibilityIdentifier.pause == "pause")
        #expect(TimerAccessibilityIdentifier.resume == "resume")
        #expect(TimerAccessibilityIdentifier.cancel == "cancel")
        #expect(TimerAccessibilityIdentifier.startBreak == "startBreak")
        #expect(TimerAccessibilityIdentifier.skipBreak == "skipBreak")
        #expect(CompactTimerAction.pause.identifier == TimerAccessibilityIdentifier.pause)
        #expect(CompactTimerAction.resume.identifier == TimerAccessibilityIdentifier.resume)
        #expect(CompactTimerAction.cancel.identifier == TimerAccessibilityIdentifier.cancel)
        #expect(CompactTimerAction.startBreak.identifier == TimerAccessibilityIdentifier.startBreak)
        #expect(CompactTimerAction.skipBreak.identifier == TimerAccessibilityIdentifier.skipBreak)
    }
}
