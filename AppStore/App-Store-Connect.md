# App Store Connect paste kit

Human-facing copy for filling App Store Connect. Do not treat this as runtime UI.

Bundle ID stays `lil.pomodoro`. New data lives in `easefocus.store`. The app does not import `pomodoro.sqlite`.

## Connect URLs

- Marketing: `https://lilyok.github.io/easefocus/pomodoro-planner/`
- Support: `https://lilyok.github.io/easefocus/pomodoro-planner/support/`
- Privacy Policy: `https://lilyok.github.io/easefocus/pomodoro-planner/privacy/`

## Name

Pomodoro Planner

## Subtitle

Timed tasks and calm focus

## Description

Pomodoro Planner helps you turn work into timed focus sessions. Keep a searchable task list, start a Pomodoro-style timer from any task, and track weekly usage in Statistics.

Need a plan? Task Adviser can generate one on device with Apple Intelligence when it is available — or you can add tasks yourself. Open Quote of the day for a real attributed quote matched to your current tasks. Quotes ship in the app and can quietly gain new lines from a public list when you are online; nothing about you is sent.

Goals, plans, and focus history stay on this device. Pomodoro Planner does not track you or use analytics.

## Keywords

focus,pomodoro,timer,planner,tasks,apple intelligence,productivity,sessions,quotes,statistics

## What’s New

Pomodoro Planner 2.0 replaces the previous experience on this listing.

This update starts fresh: the app does not import `pomodoro.sqlite`. Existing users will not see historical goals, tasks, or Pomodoro counts from the old app. New plans and sessions are stored in `easefocus.store`. The bundle ID remains `lil.pomodoro`.

Also in this update: Pomodoro task list with sticky active session, Statistics with shareable weekly graphic, Task Adviser, Quote of the day (curated famous quotes; Apple Intelligence only picks from the real list), tomato App Icon, Spanish UI chrome, and Play timer sounds (the scheduled timer-finished notification follows that toggle).

## App Review notes

- Bundle ID: `lil.pomodoro` (same listing; display name Pomodoro Planner).
- Fresh start: the app never opens or migrates `pomodoro.sqlite`. Reviewers with residual old data will not see it. New SwiftData file: `easefocus.store`.
- Apple Intelligence / Foundation Models are optional. Manual tasks and the timer work without them. When available, plan generation and quote selection run on device. Quote selection never invents text; it chooses an index from a curated attributed list.
- On launch the app may fetch a public JSON quote list from a GitHub gist (`gist.githubusercontent.com`) and merge new quotes into the local library. No user data is uploaded.
- Optional Google search: a query leaves the app only after the user taps Search Google on the confirmation sheet; the system browser opens `https://www.google.com/search?q=…`. Nothing is sent during generation or save.
- No analytics SDKs, no ATT, no account system.
- Support URL: `https://lilyok.github.io/easefocus/pomodoro-planner/support/`
- Marketing URL: `https://lilyok.github.io/easefocus/pomodoro-planner/`
- Privacy Policy URL (optional for Data Not Collected): `https://lilyok.github.io/easefocus/pomodoro-planner/privacy/`
- Suggested paths: add a task on Pomodoro → Start → confirm sticky timer card → Statistics → Quote of the day → Settings → Privacy.

## Privacy nutrition labels

**Data Not Collected.**

Pomodoro Planner does not collect data linked to identity for analytics, advertising, or developer-operated backends. Goals, plans, and session history remain on device.

Optional Google search is user-initiated: after Search Google, Safari (or the default browser) loads Google with the user-reviewed query. That handoff is not developer data collection for App Store privacy labels.

The optional quote-list fetch is a public GET; the app does not send account or task content with that request.

Declare Required Reason APIs in `EaseFocus/PrivacyInfo.xcprivacy` only (UserDefaults CA92.1; file metadata C617.1 for in-container store size). Tracking is false; no tracking domains; no collected data types in the privacy manifest.

## Screenshot shot list

Capture on device (do not generate or commit PNGs):

1. **Pomodoro** — task list with search, quote, and settings controls.
2. **Active session** — sticky pinned timer card on a running task.
3. **Statistics** — weekly usage chart.
4. **Task Adviser** — survey / generate entry.
5. **Quote of the day** — attributed quote sheet.
6. **Settings** — Privacy section visible.
