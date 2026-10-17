# SetHarbor

[![Flutter Android and iOS](https://github.com/william-gr/setharbor/actions/workflows/flutter.yml/badge.svg)](https://github.com/william-gr/setharbor/actions/workflows/flutter.yml)

A free, open-source workout tracker for **Android and iOS**, built with **Flutter and Riverpod**. It works offline, without accounts, subscriptions, advertising or a backend. The interface is in Portuguese. MIT licensed.

- Cyclic workouts A → B → C, independent of weekdays. Saving an extra session preserves the expected next workout.
- Optional weight and repetitions, hidden completed sets, drafts, immutable history and last measured performance.
- Offline catalog of 115 exercises, muscle/equipment information, session-only similar swaps and execution searches on Google.
- Rest timer, JSON plan import, portable backups and optional HTTPS plan updates.
- Short ChatGPT planning prompts and workout links with a complete preview before applying.

## Try it

The **[SetHarbor Trial page](https://william-gr.github.io/setharbor/)** distributes a separate Android APK and a sample workout link. Trial has its own data and can coexist with the personal app. [Latest main APK workflow](https://github.com/william-gr/setharbor/actions/workflows/build-apk.yml) also provides downloadable APKs with source commit and SHA256.

CI APKs use a generated development signing key. An update must retain the installed app's signing key; back up before reinstalling an app signed with another key. Automatic migration cannot bypass Android's signing checks. Never install an E2E APK on a personal phone.

iOS source and simulator builds are available; App Store/TestFlight distribution and a real iPhone check still require Apple signing and device validation. An unsigned `.app` is not an installable iPhone release.

## Development

The current app lives in **`flutter_app/`**. Use Flutter **3.47.0**, Dart 3.13, JDK 17+ and Android SDK 36. Android 8.0+ is supported. iOS development requires macOS and Xcode; the project targets iOS 15+ as configured by Flutter/Xcode.

```sh
cd flutter_app
flutter pub get --enforce-lockfile
flutter run --flavor preview                  # Android
flutter run -d <iphone-simulator-id>           # iOS simulator
```

From the repository root, build versions from the latest source commit's recorded date:

```sh
python3 scripts/build_flutter.py apk --edition personal
python3 scripts/build_flutter.py apk --edition preview
python3 scripts/build_flutter.py ios
```

Android versionName/versionCode are **YYYYMMDD**; iOS uses **YYYY.MM.DD** and build number **YYYYMMDD** to meet Apple's version syntax. Builds on the same source date share a version. Source SHA and checksums identify the exact APK. Android output: `flutter_app/build/app/outputs/apk/<edition>/release/`. The optional ignored `signing/personal-debug.jks` retains the personal Android signing identity.

## Compatibility and migration

The Android package remains `com.william.treino` (Trial `.preview`, tests `.e2e`). On the first Flutter launch, the app reads the native `training` preferences, validates and copies the complete state into an atomic JSON file. Original preferences remain intact. It preserves plans, measured/unmeasured history, legacy snapshots, drafts and exercise overrides, phase, selected workout, stable next-workout ID and the optional update URL. An invalid or failed migration displays an error instead of resetting data.

Backup **v4** and restore **v1–v4**, plan schema 1 and existing workout links remain compatible. Drafts continue to block plan replacement. See [migration architecture and verification](docs/FLUTTER_MIGRATION.md), [catalog contract](docs/EXERCISE_CATALOG.md) and [cyclic workouts](docs/CYCLIC_WORKOUTS_PROPOSAL.md).

## Tests and coverage

```sh
cd flutter_app
flutter analyze --no-pub
flutter test --branch-coverage
cd ..
python3 scripts/check_flutter_coverage.py
python3 scripts/test_flutter_coverage.py
```

The gate automatically requires **90% line / 80% branch coverage per Dart logic file**, including new helpers. Only the UI directory and entry point are excluded; widget/device tests cover those. Missing files, execution data or branch instrumentation fail the gate. Coverage: `flutter_app/coverage/lcov.info`.

```sh
cd flutter_app
flutter test integration_test/app_test.dart -d emulator-5554 --flavor e2e --no-uninstall
# Or select an iPhone simulator (without --flavor).
```

The [Flutter workflow](.github/workflows/flutter.yml) runs analysis, coverage, Android integration/OS tests on API35 and iOS simulator tests (API29 validation is deferred). Android OS tests additionally install the native baseline and update it in place to verify migration, real disk failure rollback, document export/restore/import, cold/warm links and sharing. They refuse physical devices and use only `.e2e`. iOS XCTest verifies native links, sharing and actual backup export/restore through Files, preserving its remembered destination and verifying the restored payload. See [verification report](docs/FLUTTER_MIGRATION.md).

The Java implementation in `app/`, root Gradle build and its 51 Python E2E cases remain as a migration reference. Their [legacy workflow](.github/workflows/android-e2e.yml) is manual; they do not test the Flutter interface. Their historical results are in [LOCAL_TEST_REPORT.md](e2e/LOCAL_TEST_REPORT.md).

## ChatGPT handoff

**Planejar com ChatGPT** shares a short request pointing to the [public guide and catalog](https://william-gr.github.io/setharbor/chatgpt/). **Revisar ficha com ChatGPT** also shares the sanitized plan, excluding loads, history, drafts and arbitrary metadata. The returned link opens a full confirmation preview. The app does not call an OpenAI API and requires no API key.

Android HTTPS links need the supported-links setting; the browser fallback opens an Android intent. On iOS, the browser button opens `setharbor://workout`. Verified Apple universal links are not configured on the shared GitHub Pages domain. Real ChatGPT/iPhone behavior still needs validation; simulator deep links do not prove the external ChatGPT flow. [Link contract and limitations](docs/CHATGPT_LINKS.md).

## License

[MIT](LICENSE). The app remains free. Flutter and dependencies retain their own compatible license notices.

CI device tests use native Android instrumentation and a hosted iOS XCTest to
collect the shared Dart results without Flutter tool VM-service discovery.
With exactly one disposable Android emulator attached, run
`python3 scripts/test_flutter_android.py` (requires the native E2E baseline APK).
For a booted iOS simulator, run `python3 scripts/test_flutter_ios.py --device UUID`.
Both runners retain bounded command logs and native results under `e2e/artifacts/`.
