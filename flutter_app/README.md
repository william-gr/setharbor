# SetHarbor Flutter

Shared Android/iOS app using Riverpod 3. The repository root README contains build/test commands and [the migration document](../docs/FLUTTER_MIGRATION.md) explains storage compatibility and validation.

- `lib/domain`: pure Dart contracts, catalog, session identity, sequence, backups and legacy migration.
- `lib/application`: Riverpod `AsyncNotifier` and serialized durable transactions.
- `lib/data`: native platform boundary, injectable through Riverpod.
- `lib/ui`: shared screens and foreground rest timer.
- `android` / `ios`: atomic storage, native documents/share/links and strict HTTPS fetch.
- `test`: domain, controller, channel and widget regressions.
- `integration_test`: shared device suite.
- `e2e/android_smoke.py`: real OS update and integration tests, emulator only.

Do not edit the copied JSON assets independently: canonical assets remain in `../app/src/main/assets/`; the test suite enforces byte equality. Preserve MIT licensing and never commit signing credentials.
