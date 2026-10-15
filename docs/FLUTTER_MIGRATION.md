# Flutter / Riverpod migration

The shared app is in `flutter_app/`. The native Java app stays in `app/` as an executable migration baseline, not a second actively developed UI. New APK workflows build Flutter. Existing plan/catalog/link formats are intentionally unchanged.

## Architecture

- Pure Dart: plan validation, catalog/aliases/legacy identity, optional measurements, swaps/snapshots, cyclic cursor, history, backup validation and migration.
- Riverpod 3: `assetsProvider`, injectable `platformProvider`, `AsyncNotifierProvider` for persistent workout state. No generated code or experimental Riverpod persistence. A failed initialization has no automatic retry/reset; the screen offers an explicit retry.
- Transactions: queued edits and actions operate on deep copies. The native atomic write completes before the provider publishes the next state. A failed write preserves history, cursor, selection and drafts; the next transaction can retry. Finishing writes one complete history/draft/cursor transaction.
- Small native boundary: Android Kotlin and iOS Swift implement atomic storage, system document picker, share sheet, external URL opening and link delivery. No analytics, backend, account or paid API.
- HTTPS: default platform TLS validation, no redirects, 200 only, 10-second request timeout, 1 MB streaming limit. Android network IO uses a separate executor from state writes. URL/revision/pending-link checks run again before applying; drafts block replacement.

## Data compatibility

Android application ID remains `com.william.treino`; `.preview` and `.e2e` retain their independent sandboxes. The same signing key is required to update any existing installation. The missing original personal key is not recoverable through a framework migration. CI development keys are still ephemeral; no phone is uninstalled or modified by tests.

At the first Flutter launch, the Android bridge reads every primitive from SharedPreferences `training`. Dart decodes plan/history/drafts, binds old history without snapshots to the original plan, migrates encoded or older raw next-workout IDs, validates state and writes `files/training-flutter.json` through `AtomicFile` with an explicit file sync. Original preferences are left intact. A failed validation/write never marks the migration complete. Once the Flutter file exists it is authoritative; a corrupt file fails visibly rather than silently importing stale Java data.

On iOS, the state is an atomic UTF-8 JSON file in Application Support, protected until the first device unlock. Files imported from the document picker are validated before confirmation. Export remains backup v4; restore accepts v1/v2/v3/v4, preserves optional blank measurements, movement overrides and the stable cursor. iOS document selection starts in the app Documents folder, which is exposed to Files; the private workout state remains in Application Support. The optional private update URL is local only and excluded from backups and ChatGPT prompts.

A later reinstall with a different signing key requires the existing backup flow. Migrating Android data automatically does not imply transferring data automatically to a separate iPhone; the portable backup can move between platforms.

## Links and system integration

Both platforms register `setharbor://workout#v1.PAYLOAD`. Android also registers the existing HTTPS URL; users must enable supported links because the shared Pages domain has no domain-root association file. On iOS, the Pages open button uses the custom scheme. There is no claim of verified Apple universal links or automatic ChatGPT guide retrieval.

The payload is bounded to 64,000 characters, strict Base64URL without padding and strict UTF-8. Only exact supported destinations are accepted. Plans show a complete confirmation preview. No URL from imported metadata is fetched. Current-plan sharing whitelists contract fields and never sends history, loads, drafts or arbitrary metadata.

## Builds and CI

Use `scripts/build_flutter.py` from the repository root. It reads Git's source committer date: Android YYYYMMDD for version name/code; iOS YYYY.MM.DD for marketing version and YYYYMMDD for build. iOS requires dotted numeric marketing versions; the date semantics stay the same. APK source SHA/checksum metadata remains available. iOS builds in CI are unsigned and are not an IPA distribution.

`flutter.yml` validates shared logic and runs Android API29/35 plus iOS simulator tests. iOS native tests wait until Flutter scrolling settles before tapping, use unique export filenames, and disable diagnostic collection that stalled the local simulator for ten minutes on early failures. `build-apk.yml` and `workout-links.yml` publish optimized Flutter personal/Trial APKs. `android-e2e.yml` is the manual legacy Java reference suite: its UI driver expects native widgets and is not a Flutter regression gate. It was retired from push/PR when the maintained application changed frameworks, not reported as passing. The final pre-migration run 38606014609 had 50/51 passes on each API (API29 scenario05; API35 scenario41 failed); previous local native results remain in the historical report.

Coverage requires 90% lines / 80% branches **per non-UI Dart source file**, automatically discovering new helpers. Missing coverage/instrumentation fails. The legacy Java gate remains unchanged for baseline builds. Native integration code is validated through OS/device tests rather than included in a Dart percentage.

## Local verification, 2026-10-14

- Flutter 3.47.0 / Dart3.13, Xcode27 / iOS27 simulator, AndroidAPI35 arm64 disposable emulator.
- 25 Dart/controller/channel/widget tests passed. Pure domain files: 100% lines and branches. Riverpod controller: 93.2% lines / 96.8% branches. Platform channel: 100% lines/branches. Gate passed; negative checks verify low/missing coverage and newly added logic fail.
- Three shared integration tests passed on Android and three on iOS, using actual native storage. They exercise UI completion, optional measurements, sequence, catalog/search, drafts/overrides, extras, opaque IDs, history, backup restore and reopening.
- Android OS smoke passed: native-to-Flutter update without uninstall, preserved original preferences/data, real read-only-filesystem failure with rollback/restart/retry, real export/restore/import, cold/warm link preview/cancel/apply and native share sheet. The final normal APK passed the same full OS smoke after UI/IO refinements. Native HTTPS also passed with trusted fixture TLS: higher revision preserves history, redirects/HTTP503/over1MB responses are rejected without changing the plan.
- Personal/Trial release APKs and unsigned iOS device/simulator builds compiled. Personal/Trial release lint and E2E debug lint passed. Two native iOS XCUITests passed, including fresh sharing, cold/warm links, document export to a uniquely named file, restore/confirmation and sharing again after restore. XCTest waits for a stable Flutter accessibility frame because UIKit idle checks do not include Flutter scroll physics.
- API29 and GitHub Actions checks for the Flutter migration are pending until the commit is pushed. A real iPhone and real ChatGPT handoff remain unverified; no personal phone was touched.
