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

At the first Flutter launch, the Android bridge reads every primitive from SharedPreferences `training`. Dart decodes plan/history/drafts, binds old history without snapshots to the original plan, migrates encoded or older raw next-workout IDs, validates state and writes `files/training-flutter.json` through a sibling temporary file with explicit file sync and a checked atomic `Os.rename`. Original preferences are left intact. A failed validation/write never marks the migration complete. Once the Flutter file exists it is authoritative; a corrupt file fails visibly rather than silently importing stale Java data.

On iOS, the state is an atomic UTF-8 JSON file in Application Support, protected until the first device unlock. Files imported from the document picker are validated before confirmation. Export remains backup v4; restore accepts v1/v2/v3/v4, preserves optional blank measurements, movement overrides and the stable cursor. iOS document selection uses the location managed by Files, including external storage; the private workout state remains in Application Support. The optional private update URL is local only and excluded from backups and ChatGPT prompts.

A later reinstall with a different signing key requires the existing backup flow. Migrating Android data automatically does not imply transferring data automatically to a separate iPhone; the portable backup can move between platforms.

## Links and system integration

Both platforms register `setharbor://workout#v1.PAYLOAD`. Android also registers the existing HTTPS URL; users must enable supported links because the shared Pages domain has no domain-root association file. On iOS, the Pages open button uses the custom scheme. There is no claim of verified Apple universal links or automatic ChatGPT guide retrieval.

The payload is bounded to 64,000 characters, strict Base64URL without padding and strict UTF-8. Only exact supported destinations are accepted. Plans show a complete confirmation preview. No URL from imported metadata is fetched. Current-plan sharing whitelists contract fields and never sends history, loads, drafts or arbitrary metadata.

## Builds and CI

Use `scripts/build_flutter.py` from the repository root. It reads Git's source committer date: Android YYYYMMDD for version name/code; iOS YYYY.MM.DD for marketing version and YYYYMMDD for build. iOS requires dotted numeric marketing versions; the date semantics stay the same. APK source SHA/checksum metadata remains available. iOS builds in CI are unsigned and are not an IPA distribution.

`flutter.yml` validates shared logic and runs Android API35 plus iOS simulator tests (API29 deferred at the user’s request). iOS native tests wait until Flutter scrolling settles before tapping, use a unique backup payload and verify restoration after replacing the active plan, and disable diagnostic collection that stalled the local simulator for ten minutes on early failures. `build-apk.yml` and `workout-links.yml` publish optimized Flutter personal/Trial APKs. `android-e2e.yml` is the manual legacy Java reference suite: its UI driver expects native widgets and is not a Flutter regression gate. It was retired from push/PR when the maintained application changed frameworks, not reported as passing. The final pre-migration run 38606014609 had 50/51 passes on each API (API29 scenario05; API35 scenario41 failed); previous local native results remain in the historical report.

Coverage requires 90% lines / 80% branches **per non-UI Dart source file**, automatically discovering new helpers. Missing coverage/instrumentation fails. The legacy Java gate remains unchanged for baseline builds. Native integration code is validated through OS/device tests rather than included in a Dart percentage.

## Local verification, 2026-10-14

- Flutter 3.47.0 / Dart3.13, Xcode27 / iOS27 simulator, AndroidAPI35 arm64 disposable emulator.
- 26 Dart/controller/channel/widget tests passed. Pure domain files: 100% lines and branches. Riverpod controller: 93.2% lines / 96.8% branches. Platform channel: 100% lines/branches. Gate passed; negative checks verify low/missing coverage and newly added logic fail.
- Three shared integration tests passed on Android and three on iOS, using actual native storage. They exercise UI completion, optional measurements, sequence, catalog/search, drafts/overrides, extras, opaque IDs, history, backup restore and reopening.
- Android OS smoke passed: native-to-Flutter update without uninstall, preserved original preferences/data, real read-only-filesystem failure with rollback/restart/retry, real export/restore/import, cold/warm link preview/cancel/apply and native share sheet. The final normal APK passed the same full OS smoke after UI/IO refinements. Native HTTPS also passed with trusted fixture TLS: higher revision preserves history, redirects/HTTP503/over1MB responses are rejected without changing the plan.
- Personal/Trial release APKs and unsigned iOS device/simulator builds compiled. Personal/Trial release lint and E2E debug lint passed. Two native iOS XCUITests passed, including fresh sharing, cold/warm links, document export to a real file, restore/confirmation and sharing again after restore. XCTest waits for a stable Flutter accessibility frame because UIKit idle checks do not include Flutter scroll physics.
- The initial Flutter CI run 38666890553 exposed a storage-failure regression on API29; API35/iOS timed out at Flutter tool test startup. The API29 implementation of `AtomicFile` could log a failed backup rename and still truncate the original. The checked temporary-file replacement fixes that path; `AtomicFile.openRead` remains only for recovering older backups. CI now uses native Android instrumentation and a hosted iOS XCTest to collect the same three Dart scenarios without VM-service discovery. Each command is bounded and retains logs/results. Full CI revalidation is pending. A real iPhone and real ChatGPT handoff remain unverified; no personal phone was touched.

The rest timer has a stable key and explicitly keeps its state when scrolled out of the lazy list, including when the extra-workout action changes list positions. A widget regression starts it, scrolls offscreen, reorders the list, returns and verifies the countdown is still active before stopping it.


## CI failure follow-up, 2026-10-15

The checked Android writer and native CI runners passed local verification:
three shared Dart scenarios via Android instrumentation, the full Android OS
migration/disk-failure/documents/links/share suite, HTTPS checks and E2E lint;
three shared Dart scenarios in one hosted iOS XCTest plus two native UI tests,
with no failures or skips. XCTest summary checks reject missing, skipped or
failed cases. The hosted case separately requires all three Dart results.
The 26 Flutter tests, coverage gate, analyzer, personal/Trial release builds and
lint, unsigned iOS release build, six web tests and guide consistency check passed.
Logs and native results are retained under `e2e/artifacts/flutter-integration/`
and `e2e/artifacts/flutter-ios-integration/`. GitHub API35/iOS revalidation
remains pending until this fix is pushed and that run completes.


Follow-up run 38775026530: Android35 passed the complete suite. Android29 passed
all three shared tests, migration and the real disk-failure regression, then
failed in the HTTPS UI driver; further API29 work is deferred at the user's
request. The iOS hosted case reported all three Dart scenarios passing and fresh
sharing passed. The export UI test saw Save before the filename field existed
on the cold iOS26 Files provider; it now waits for the editable filename and
an enabled Save button before interacting, preserving the actual export/restore
assertions. Simulator startup is bounded with progress on stderr, allowing the
seven-minute cold startup observed in CI without consuming the whole job.


Run 38784938584 found a shared-driver timing issue on Android35: Flutter scroll
inertia moved a button between the accessibility dump and the touch, so the
HTTPS modal did not open and the driver typed into a workout field. The Flutter
OS driver now requires a stable accessibility frame before one touch and checks
that the URL modal exists before typing. It never retries a failed touch.
The hosted iOS run also exposed a platform-owned accessibility handle being
created during the first test. Integration setup enables platform semantics
before test baselines and restores the override after the suite; app handle
leak assertions and accessibility remain enabled. See the related framework
[UiAutomation issue](https://github.com/flutter/flutter/issues/129231).


Local validation after these timing fixes: analyzer, 26 tests and per-file
coverage gate passed; Android instrumentation reported three passing scenarios;
the Android OS suite and all HTTPS rejection cases passed with stable touches;
the hosted iOS case reported all three Dart scenarios passing, followed by two
passing native iOS UI cases with no skips. Final remote CI is still pending.


## Native backup compatibility follow-up, 2026-10-16

Run 38885486422 passed unit/coverage and the full Android35 suite. The hosted iOS
case reported all three Dart scenarios passing; native sharing passed, while the
export picker still had Save disabled and no filename editor on the CI SDK26
build. The exact iOS26.4.1 runtime was installed locally and a clean installation
passed the existing UI tests under SDK27, confirming the CI behavior is not
reproduced by runtime version alone.

The bridge now lets Files manage the selected location instead of forcing the
app's Documents sandbox. The native regression validates the supported export
operation without requiring a particular filename editor: it exports a uniquely
identified plan, applies a different plan, restores the actual file through Files
and asserts that the original unique title returns. Existing-file replacement
uses the system confirmation. The initial iOS26.4.1 content roundtrip passed;
final SDK26 CI validation remains pending.

The native content roundtrip passed on a clean iOS26 simulator and on a repeat
with an existing backup, including the system Replace confirmation. CI also
retains the unsigned simulator app bundle so SDK-specific behavior can be
reproduced locally from the exact CI build if needed.

The final native test explicitly creates a uniquely named folder at the On My
iPhone root through Files, exports there, changes the plan, reopens that exact
folder and restores the backup's unique payload. This avoids stale app-folder
locations and proves the export is outside the app sandbox. Both native tests
passed on iOS27 with this external-folder flow. This replaces assumptions about
a particular filename editor and app-folder overwrite behavior; actual save,
restore, content equality, link and share assertions remain mandatory.

Final local external-folder validation passed: two native cases on iOS26.4.1,
two on iOS27, and the unsigned iOS release build. SDK26 CI revalidation remains
pending; Android35 full CI and shared Dart tests were already green on fd9afbe.


The automatic aeff763 run passed Android35 and shared iOS scenarios, then found
a race in the new-folder test helper: Files asynchronously entered the newly
created directory while the helper was trying to tap its old parent cell. The
helper now waits for the destination navigation title without that redundant
touch. Both native tests passed locally against the exact unmodified SDK26 app
bundle downloaded from CI, running on iOS26.4.1 (23E254a). The local XCTest
configuration pointed its UI target at that artifact; only executable permission
bits lost by artifact packaging were restored. Result:
`/tmp/setharbor-ci-sdk26-app/probe.xcresult`, two passes, no skips/failures.


Run 38897044207 again passed unit/coverage, Android35 and all three shared iOS
scenarios. The complete native log identified an earlier cold-provider race:
Files exposed More before its location/back controls, so the helper checked them
too soon and waited for a root it had never navigated to. The helper now waits
for a visible, hittable root/back/location before choosing its navigation action.
Both native cases passed on a newly created iOS26.4.1 simulator against that
run's exact SDK26 app bundle, with no failures or skips. Evidence:
`/tmp/setharbor-ci-sdk26-cold/probe.xcresult`. Remote revalidation is pending.
Android29 remains deferred by user request; Android35 and iOS remain required.


Run 38905149159 passed unit/coverage and the complete Android35 job. The iOS
navigation wait worked, but the Files inline rename remained focused after an
injected newline. Its accessibility tree exposed the real keyboard Done button.
The test now taps that button to commit the name. Both native cases passed with
the exact b7c04e6 SDK26 CI app on iOS26.4.1, result
`/tmp/setharbor-ci-done/probe.xcresult`. No application behavior or backup
assertions changed; remote iOS revalidation remains required.
