# SetHarbor

[![Android E2E](https://github.com/william-gr/setharbor/actions/workflows/android-e2e.yml/badge.svg)](https://github.com/william-gr/setharbor/actions/workflows/android-e2e.yml)

A free, open-source Android workout tracker. Record your sets, keep your workout history and update your training plan without rebuilding the app.

SetHarbor works offline, with no account, subscription or advertising. The current interface is in Portuguese. Android 8.0 or later is required.

## Features

- Offline catalog with 90 exercises, muscle groups, muscles and equipment.
- One-button random similar exercise swaps for the current session, with separate load history.
- Custom training plans with up to seven days, imported as JSON.
- Weight and repetitions for each set, with completed sets hidden and available to review or undo.
- Persistent drafts, previous exercise values and workout history.
- Adaptation phases and a 60/90/120-second rest timer.
- JSON backup and restore, including the active plan, history and drafts.
- Optional HTTPS plan updates when opening the app; workout history stays on the device.

The bundled five-day plan is an example. Import a compatible plan to use your own routine. Plan changes are blocked while drafts exist, and saved sessions retain their original plan.

## Build

Use JDK 17 and Android SDK 35. The Gradle wrapper pins Gradle 8.9 and the project uses Android Gradle Plugin 8.7.3.

```sh
./gradlew testDebugUnitTest assembleDebug lintDebug
```

Run `./gradlew coreCoverageVerification` to execute the JVM tests, generate HTML/XML reports and enforce **90% line / 80% branch coverage for each core class**. The gate also runs through `check` and before CI emulator tests. It covers all application Java classes except `MainActivity`, its nested classes, and generated Android classes. Real-UI E2E tests cover the Activity. New core classes are included automatically. Missing classes, tests or execution data fail the gate. Reports: `app/build/reports/jacoco/coreCoverageReport/`.

The APK is written to `app/build/outputs/apk/debug/app-debug.apk`. Windows users can use `gradlew.bat`. CI produces development APKs; no Play Store release is published yet. Keep the same signing key when updating an existing installation.

### Download the latest main APK

[Build latest main APK](https://github.com/william-gr/setharbor/actions/workflows/build-apk.yml) runs on pushes to `main` and can also be started with **Run workflow**. It always checks out the latest `main`, runs JVM tests, the coverage gate and lint, and uploads a downloadable APK artifact for 30 days. No tag is required.

Both `versionName` and `versionCode` use the source commit's recorded committer date as `YYYYMMDD` (not the build date). Builds from the same day share the version; the filename `SetHarbor-YYYYMMDD-COMMIT.apk`, `build-info.json` and `SHA256SUMS` identify the exact source and APK. Local builds use the same rule; source archives without Git can pass `-PappVersionDate=YYYYMMDD`.

These APKs use a CI-generated debug key, which changes between runners. They cannot replace an installation signed with another key; preserve the original signing key and export a backup before replacing an existing installation. E2E APKs and fixture certificates are excluded from this downloadable app.

## Tests

```sh
./gradlew assembleE2e
E2E_APK="$PWD/app/build/outputs/apk/e2e/app-e2e.apk" \
ANDROID_SERIAL=emulator-5554 python3 e2e/run.py
```

The 35 E2E scenarios use the real Android interface and document picker. They run only on emulators and clear only the separate E2E application. See [E2E instructions](e2e/README.md) and [local execution report](e2e/LOCAL_TEST_REPORT.md).

GitHub Actions builds, runs lint and executes E2E on Android APIs 29 and 35 for pull requests, pushes to `main` and manual runs. Logs, screenshots and results are retained as artifacts. All 35 scenarios passed locally on API 35 and in CI on both APIs 29 and 35, without skips; see the local report for verified results, environments and fixes.

## Plans and compatibility

See [exercise catalog](docs/EXERCISE_CATALOG.md) for session swaps and exercise identity. See [CLAUDE.md](CLAUDE.md) for the JSON schema, architecture and persistence rules. The legacy application ID `com.william.treino` and JSON format identifier `meu-treino-plan` are retained for installed-app and backup compatibility.

HTTPS updates require a reachable URL with a trusted certificate, a direct JSON response and a greater plan revision. No server is configured by default. The app has no direct ChatGPT or MCP connection; an external integration can publish the JSON to a configured HTTPS endpoint.

The rest timer is intended for foreground use. Export backups before uninstalling or replacing your installation.

## Contributing and license

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) and [TODO.md](TODO.md). SetHarbor is available under the [MIT license](LICENSE), free to use, modify and redistribute.
