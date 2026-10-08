# Contributing to SetHarbor

Open an issue describing a reproducible problem or a proposed improvement. For a pull request, explain the resulting behavior and the checks you ran.

Use JDK 17 and SDK 35. Run `./gradlew assembleDebug assembleE2e lintDebug`, then run the E2E suite on an emulator as described in `e2e/README.md`. Report checks that could not run. CI covers Android APIs 29 and 35.

Preserve historical plan snapshots, exercise IDs, backup compatibility and persisted drafts. Do not commit signing keys or personal workout records. The E2E fixture certificate must remain confined to the E2E build.

See `CLAUDE.md` for architecture and data contracts. Useful future contributions include English localization, broader accessibility support and additional automated test coverage. Contributions are provided under the project's MIT license.
