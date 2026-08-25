# EaseFocus

EaseFocus is a modern Pomodoro planner for turning personal goals into practical, timed tasks.

The app uses Apple’s Foundation Models framework to create personalized plans on supported devices, while keeping manual planning and the Pomodoro timer available to everyone.

## Status

Phase 0 foundation: multiplatform Xcode project, module folders, design tokens, CI, a Foundation Models availability prototype, and Google-search privacy copy.

## Platform

- SwiftUI lifecycle
- iOS 26+ and macOS 26+
- Swift 6
- SwiftData
- Foundation Models, with a runtime availability check

macOS is included as a second destination on the same app target so the project can run while an iOS Simulator runtime is unavailable. The product remains iOS-first.

## App Store identity

EaseFocus updates the existing Pomodoro App Store listing. The bundle identifier stays `lil.pomodoro`.

The first release does **not** import the old Core Data store. Existing users who update will not see historical goals or Pomodoro counts until a later, explicit migration if we decide to add one.

## Privacy

Plan generation runs on device when Apple Intelligence is available. Optional Google search sends only the search query, and only after an explicit tap on Search Google. Generated plans and survey answers stay local.
