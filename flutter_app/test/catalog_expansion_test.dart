import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:setharbor/domain/catalog.dart';
import 'package:setharbor/domain/plan.dart';
import 'package:setharbor/domain/workout_state.dart';

Json readJson(String path) => jsonDecode(File(path).readAsStringSync()) as Json;

void main() {
  final original = readJson('assets/default-plan.json');
  final data = readJson('assets/exercise-catalog.json');
  final baseline = readJson('test/fixtures/catalog_revision1_identity.json');
  final catalog = Catalog(data, original);
  final added = catalog.exercises.values
      .where((row) => !baseline.containsKey(row['id']))
      .toList();

  test(
    'revision 1 names, aliases and substitution identities survive expansion',
    () {
      expect(baseline.length, 90);
      for (final entry in baseline.entries) {
        final current = catalog.exercises[entry.key]!;
        final previous = entry.value as Json;
        for (final key in previous.keys) {
          expect(current[key], previous[key], reason: '${entry.key}: $key');
        }
        for (final name in [
          ...previous['name'].values,
          ...previous['aliases'],
        ]) {
          expect(
            catalog.resolve({'name': '  ${name.toUpperCase()}  '})?['id'],
            entry.key,
          );
        }
      }
      // Restore every formerly valid automatic swap with the expanded catalog.
      final oldData = clone(data);
      oldData['exercises'] = data['exercises']
          .where((row) => baseline.containsKey(row['id']))
          .toList();
      final oldCatalog = Catalog(oldData, original);
      for (final source in oldCatalog.exercises.values) {
        for (final target in oldCatalog.alternatives(source)) {
          final plan = clone(original);
          exercisesOf(plan, 0)[0].addAll({
            'catalogId': source['id'],
            'name': oldCatalog.name(source),
          });
          final state = migrateLegacy({}, plan, oldCatalog);
          oldCatalog.switchTo(plan, 0, 0, state.draft, target['id']);
          for (final version in [3, 4]) {
            final backup = state.backup()..['version'] = version;
            final restored = restoreBackup(backup, original, catalog);
            expect(
              catalog.effective(
                exercisesOf(restored.plan, 0)[0],
                restored.draft,
              )['catalogId'],
              target['id'],
            );
          }
        }
      }
    },
  );

  test(
    'new entries have traceable sources and survive saved history and backup',
    () {
      expect(data['revision'], 2);
      expect(added.length, 25);
      final sources = {for (final row in data['sources']) row['id']: row};
      expect(sources.length, data['sources'].length);
      for (final row in added) {
        expect(row['aliases'], isNotEmpty);
        expect(row['sourceIds'], isNotEmpty);
        expect(row['notes'], isNotEmpty);
        for (final sourceId in row['sourceIds']) {
          expect(sources.containsKey(sourceId), true, reason: row['id']);
          final url = Uri.parse(sources[sourceId]['url']);
          expect(url.scheme, 'https');
          expect(url.host, isNotEmpty);
        }
        for (final name in [...row['name'].values, ...row['aliases']]) {
          expect(catalog.resolve({'name': name})?['id'], row['id']);
        }
        final plan = clone(original);
        exercisesOf(
          plan,
          0,
        )[0].addAll({'catalogId': row['id'], 'name': catalog.name(row)});
        validatePlan(plan);
        final state = migrateLegacy({}, plan, catalog);
        state.draft['0_0done'] = true; // No invented load/repetition required.
        state.finish(catalog, DateTime(2026, 10, 17));
        final restored = restoreBackup(state.backup(), original, catalog);
        expect(
          exercisesOf(restored.history.single['plan'], 0)[0]['catalogId'],
          row['id'],
        );
        expect(restored.history.single['sets']['0_0kg'], '');
        expect(restored.history.single['sets']['0_0reps'], '');
      }
    },
  );

  test('home options require no hidden bench, machine or ankle attachment', () {
    Set<String> available(Set<String> equipment) => catalog.exercises.values
        .where(
          (row) =>
              equipment.containsAll((row['equipment'] as List).cast<String>()),
        )
        .map((row) => row['id'] as String)
        .toSet();
    final home = available({'bodyweight', 'mat'});
    expect(
      home,
      containsAll([
        'bodyweight-squat',
        'bodyweight-reverse-lunge',
        'bodyweight-glute-bridge',
        'bodyweight-standing-calf-raise',
        'side-lying-hip-abduction',
        'dead-bug',
        'bird-dog',
        'reverse-crunch',
      ]),
    );
    final dumbbells = available({'bodyweight', 'mat', 'dumbbells'});
    expect(
      dumbbells,
      containsAll([
        'standing-dumbbell-shoulder-press',
        'dumbbell-bent-over-row',
        'dumbbell-floor-press',
      ]),
    );
    expect(dumbbells, isNot(contains('dumbbell-bulgarian-split-squat')));
    expect(dumbbells, isNot(contains('dumbbell-step-up')));
    expect(available({'cable'}), isNot(contains('cable-hip-abduction')));
    expect(
      available({'cable', 'ankle-cuff'}),
      containsAll(['cable-hip-abduction', 'cable-hip-kickback']),
    );
  });

  test(
    'expanded swaps preserve roles and exclude time and band destinations',
    () {
      Set<String> alternatives(String id) => catalog
          .alternatives(catalog.exercises[id])
          .map((row) => row['id'] as String)
          .toSet();
      expect(alternatives('machine-leg-extension'), {
        'single-leg-machine-leg-extension',
      });
      expect(alternatives('machine-hip-abduction'), {
        'cable-hip-abduction',
        'side-lying-hip-abduction',
      });
      expect(alternatives('barbell-shrug'), {'dumbbell-shrug'});
      for (final id in [
        'dumbbell-pullover',
        'cable-hip-kickback',
        'ez-bar-reverse-curl',
        'dumbbell-wrist-curl',
        'dumbbell-wrist-extension',
        'dead-bug',
        'bird-dog',
        'reverse-crunch',
      ]) {
        expect(alternatives(id), isEmpty, reason: '$id has a distinct role');
      }
      for (final row in catalog.exercises.values) {
        for (final target in catalog.alternatives(row)) {
          expect(target['loadUnit'], isNot('band'));
          expect(target['mechanic'], isNot('isometric'));
        }
      }
      expect(
        alternatives('standing-machine-calf-raise'),
        isNot(contains('seated-machine-calf-raise')),
      );
      expect(
        alternatives('barbell-romanian-deadlift'),
        isNot(contains('seated-leg-curl')),
      );
    },
  );
}
