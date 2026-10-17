# Offline exercise catalog

SetHarbor bundles 115 exercises, 13 groups and 37 muscles in `app/src/main/assets/exercise-catalog.json`. The catalog is original, manually curated data distributed with the project under MIT. Portuguese and English names, aliases, primary/secondary/stabilizer muscles, equipment, movement patterns, substitution families and load units share stable IDs. Reference links are included in the JSON; no external API, paid service, images or network access is required.

A [coverage audit dated 2026-10-17](EXERCISE_CATALOG_AUDIT.md) records the original 90-exercise baseline. [Revision 2](EXERCISE_CATALOG_REVISION_2.md) implements its first 25 additions, with equipment coverage, classification decisions and validation results.

Revision 2 adds optional `sourceIds` on the 25 new records, referencing the root `sources` table. These are editorial references, never fetched automatically. Existing records and schema 1 remain unchanged. New descriptions are original project text; third-party images and descriptions are not bundled.

## Plans and identity

An exercise's `id` continues to identify its position in a plan. Optional `catalogId` identifies the actual movement across positions and days. For example:

```json
{"id":"monday-press", "catalogId":"barbell-bench-press", "name":"Supino reto barra", "sets":3, "reps":"6–8"}
```

Custom exercises and future catalog references remain valid plan entries. An unrecognized explicit `catalogId` never falls back to a different exercise by name. Older plans resolve known Portuguese/English names and aliases. Original `legacy-*` IDs also keep their established identity when a plan revision renames the exercise. Importers must preserve an ID only for the same movement, and use explicit catalog IDs to remove ambiguity in combined names such as “máquina / halteres”.

## Random session swaps

“Trocar por similar” immediately selects a uniformly random other exercise from the same group, substitution family, movement pattern and mechanic. Each press excludes the current movement. There is no alternative search, picker or confirmation. Sets and rep prescription remain those of the planned position.

The current kg/repetition interface excludes elastic-band and isometric alternatives. If there is no compatible alternative, the app leaves the session intact and shows a message. Similarity is a catalog classification, not a claim that loads, equipment or execution are interchangeable. Exercise information is hidden by default. The info icon toggles muscle groups, muscles, equipment, load units and notes inline. The small swap icon in the header performs the immediate random change. Both icons retain 48 dp touch targets and accessible descriptions. Equipment and load units are available in the details; assisted exercises record assistance, dumbbells record per dumbbell, and bodyweight uses zero kg without added load.

Any entered kg/reps or checked set blocks switching that position, including sets hidden by the adaptation phase. Clearing the values and checks allows switching again. Other exercises' draft values remain intact.

Session overrides are stored inside `draft<N>.exerciseOverrides`, keyed by plan position ID. They survive restart and backups v3/v4. Current exports use v4 (including the cyclic workout cursor); imports still accept v1–v4. V3 introduced explicit overrides so older apps cannot silently attach their weights to the planned exercise. Overrides are validated before a backup replaces state. A saved history entry contains the effective plan snapshot with actual exercise names/catalog IDs. The active plan is not changed. Saving clears that day's draft, so the next session starts with the planned exercises. Last-performance lookup uses catalog identity when known and preserves custom/legacy ID compatibility.

## Validation

Flutter: `flutter analyze --no-pub`, `flutter test --branch-coverage` and `python3 scripts/check_flutter_coverage.py` (the last command from the repository root). Expansion tests freeze revision-1 names/families, restore every old eligible swap and round-trip all 25 new exercises through history/backups. Android and Flutter assets must remain byte-identical.

Legacy Android: `./gradlew coreCoverageVerification` checks catalog references, legacy identity, movement families, data protection, session isolation, snapshot immutability and malformed overrides. E2E scenarios 31–35 exercise random swaps, restart, blocked changes, real document export/restore and load separation through the Android UI. All previous scenarios remain in the suite.
