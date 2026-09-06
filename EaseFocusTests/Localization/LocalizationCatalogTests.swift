import Foundation
import Testing
@testable import EaseFocus

@MainActor
struct LocalizationCatalogTests {
    @Test
    func estimatedSessionsPicksEnglishPluralVariants() {
        #expect(TaskCopy.estimatedSessions(0).localized(L10n.english) == "0 estimated sessions")
        #expect(TaskCopy.estimatedSessions(1).localized(L10n.english) == "1 estimated session")
        #expect(TaskCopy.estimatedSessions(2).localized(L10n.english) == "2 estimated sessions")
    }

    @Test
    func spokenRemainingPicksEnglishPluralVariantsForSeconds() {
        #expect(
            TimerAccessibilityPresentation.spokenRemaining(seconds: 0, locale: L10n.english)
                == "0 seconds remaining"
        )
        #expect(
            TimerAccessibilityPresentation.spokenRemaining(seconds: 1, locale: L10n.english)
                == "1 second remaining"
        )
        #expect(
            TimerAccessibilityPresentation.spokenRemaining(seconds: 2, locale: L10n.english)
                == "2 seconds remaining"
        )
    }

    @Test
    func countLineSubstitutionsKeepEnglishNounsStable() {
        #expect(
            ProgressCopy.countLine(completed: 0, broken: 0, focused: "0:00").localized(L10n.english)
                == "0 completed · 0 broken · 0:00 focused"
        )
        #expect(
            ProgressCopy.countLine(completed: 1, broken: 1, focused: "1:00").localized(L10n.english)
                == "1 completed · 1 broken · 1:00 focused"
        )
        #expect(
            ProgressCopy.countLine(completed: 2, broken: 3, focused: "2:00").localized(L10n.english)
                == "2 completed · 3 broken · 2:00 focused"
        )
    }

    @Test
    func catalogContainsSpanishForHighTrafficChrome() {
        #expect(AppCopy.today.localized(L10n.spanish) == "Hoy")
        #expect(AppCopy.plans.localized(L10n.spanish) == "Planes")
        #expect(AppCopy.progress.localized(L10n.spanish) == "Progreso")
        #expect(AppCopy.settings.localized(L10n.spanish) == "Ajustes")
        #expect(AppCopy.startFocus.localized(L10n.spanish) == "Empezar enfoque")
        #expect(AppCopy.cancel.localized(L10n.spanish) == "Cancelar")
        #expect(AppCopy.confirm.localized(L10n.spanish) == "Confirmar")
        #expect(ProgressCopy.emptyTitle.localized(L10n.spanish) == "Aún no hay sesiones")
    }
}
