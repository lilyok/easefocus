import SwiftUI

enum FocusTypography {
    static let timer: Font = .system(.largeTitle, design: .monospaced).monospacedDigit()
    static let timerFitted: Font = .system(.title, design: .monospaced).monospacedDigit()
    static let compactTimer: Font = .system(.title2, design: .monospaced).monospacedDigit()
    static let title: Font = .title2.weight(.semibold)
    static let body: Font = .body
    static let footnote: Font = .footnote
}
