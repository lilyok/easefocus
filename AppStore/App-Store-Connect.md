# App Store Connect paste kit

Human-facing copy for filling App Store Connect. Do not treat this as runtime UI.

Bundle ID stays `lil.pomodoro`. New data lives in `easefocus.store`. EaseFocus does not import `pomodoro.sqlite`.

## Name

EaseFocus

## Subtitle

Calm plans and focus sessions

## Description

EaseFocus turns a personal goal into timed focus sessions. Create a plan manually, or generate a draft on device with Apple Intelligence when it is available — then review every task before it is saved.

Start a Pomodoro-style timer from any task, refine a plan without losing completed work, and see weekly progress without streak shame. Optional Google search suggestions stay in the app until you confirm Search Google, which opens only that query in your browser.

Goals, survey answers, generated plans, and focus history stay on this device. EaseFocus does not track you or use analytics.

## Keywords

focus,pomodoro,timer,planner,goals,apple intelligence,productivity,sessions,tasks,calm

## What’s New

EaseFocus replaces the previous Pomodoro app experience on this listing.

This update starts fresh: EaseFocus does not import `pomodoro.sqlite`. Existing users will not see historical goals, tasks, or Pomodoro counts from the old app. New plans and sessions are stored in `easefocus.store`. The bundle ID remains `lil.pomodoro`.

Also in this update: on-device plan generation when Apple Intelligence is available, plan refine and history, weekly progress, Spanish UI chrome, App Icon, clearer privacy explanations in Settings, sessions-before-long-break in Settings, and Play timer sounds (the scheduled timer-finished notification follows that toggle).

## App Review notes

- Bundle ID: `lil.pomodoro` (same listing; product name EaseFocus).
- Fresh start: the app never opens or migrates `pomodoro.sqlite`. Reviewers with residual old data will not see it. New SwiftData file: `easefocus.store`.
- Apple Intelligence / Foundation Models are optional. Manual plan creation and the timer work without them. On supported devices with Apple Intelligence enabled, plan generation runs on device.
- Optional Google search: a query leaves the app only after the user taps Search Google on the confirmation sheet; the system browser opens `https://www.google.com/search?q=…`. Nothing is sent during generation or save.
- No analytics SDKs, no ATT, no account system, no privacy-policy URL required for Data Not Collected.
- Suggested paths: create a manual plan → start focus from Today → open Progress → Settings → Privacy.

## Privacy nutrition labels

**Data Not Collected.**

EaseFocus does not collect data linked to identity for analytics, advertising, or developer-operated backends. Goals, survey answers, plans, and session history remain on device.

Optional Google search is user-initiated: after Search Google, Safari (or the default browser) loads Google with the user-reviewed query. That handoff is not developer data collection for App Store privacy labels.

Declare Required Reason APIs in `EaseFocus/PrivacyInfo.xcprivacy` only (UserDefaults CA92.1; file metadata C617.1 for in-container store size). Tracking is false; no tracking domains; no collected data types in the privacy manifest.

## Screenshot shot list

Capture on device (do not generate or commit PNGs):

1. **Today** — next task + Start focus (or empty state with Create plan).
2. **Plans** — active plan list (or empty state).
3. **Timer** — running focus with remaining time and progress ring.
4. **Progress** — weekly summary + momentum days.
5. **Refine confirm** — refinement preview with Confirm as the next step.
6. **Search Google confirm** — confirmation sheet showing the quoted query.
