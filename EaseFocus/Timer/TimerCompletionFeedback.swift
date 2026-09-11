import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Lightweight completion feedback. Honors system haptics/silent settings via platform APIs.
enum TimerCompletionFeedback {
    enum Kind {
        case completed
        case cancelled
    }

    static func play(_ kind: Kind, playsSound: Bool) {
        switch kind {
        case .completed:
            playHaptic(success: true)
            if playsSound {
                TimerAlertSound.play()
            }
        case .cancelled:
            playHaptic(success: false)
        }
    }

    private static func playHaptic(success: Bool) {
        #if os(iOS)
        if success {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #elseif os(macOS)
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(
            success ? .levelChange : .generic,
            performanceTime: .default
        )
        #endif
    }
}
