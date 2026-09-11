# EaseFocus

EaseFocus is a modern Pomodoro planner for turning personal goals into practical, timed tasks.

The app uses Apple’s Foundation Models framework to create personalized plans on supported devices, while keeping manual planning and the Pomodoro timer available to everyone.

## Status

First-release candidate / App Store listing (`lil.pomodoro`). Paste kit and screenshot shot list live in `AppStore/App-Store-Connect.md`.

## Platform

- SwiftUI lifecycle
- iOS 26+ and macOS 26+
- Swift 6
- SwiftData
- Foundation Models, with a runtime availability check

macOS is included as a second destination on the same app target so the project can run while an iOS Simulator runtime is unavailable. The product remains iOS-first.

## App Store identity

EaseFocus updates the existing Pomodoro App Store listing. The bundle identifier stays `lil.pomodoro`.

EaseFocus starts fresh and does not import historical goals or Pomodoro counts from the previous app. New data is stored in the SwiftData file `easefocus.store`.

## Privacy

Goals, survey answers, generated plans, and focus history stay on this device. EaseFocus does not track you or use analytics. Plan generation runs on device when Apple Intelligence is available. Optional Google search sends only the search query, and only after an explicit tap on Search Google.

## Live Foundation Models evaluations

Normal CI uses deterministic clients and does not invoke the on-device model. To run the opt-in live evaluation suite, close any running EaseFocus app, enable Apple Intelligence, and use a supported system language:

```sh
EASEFOCUS_RUN_LIVE_MODEL_EVALS=1 xcodebuild \
  -project EaseFocus.xcodeproj \
  -scheme EaseFocus \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:EaseFocusTests/LiveDraftPlanGenerationEvaluationTests \
  test
```

The suite is disabled unless the environment variable is set. Individual locale cases return cleanly when the installed Foundation Model does not support that locale.
