import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:setharbor/domain/plan.dart';
import 'package:setharbor/domain/catalog.dart';
import 'package:setharbor/domain/links.dart';
import 'package:setharbor/domain/workout_state.dart';

Json asset(String name) =>
    jsonDecode(File('assets/$name.json').readAsStringSync()) as Json;
void main() {
  late Json original, rawCatalog;
  late Catalog catalog;
  setUp(() {
    original = asset('default-plan');
    rawCatalog = asset('exercise-catalog');
    catalog = Catalog(rawCatalog, original);
  });
  WorkoutState fresh() => migrateLegacy({}, original, catalog);
  test('canonical assets are byte-identical to native assets', () {
    for (final name in ['default-plan', 'exercise-catalog']) {
      expect(
        File('assets/$name.json').readAsStringSync(),
        File('../app/src/main/assets/$name.json').readAsStringSync(),
      );
    }
  });
  test('plan retains unknown metadata and supports 1 to 7 workouts', () {
    for (var n = 1; n <= 7; n++) {
      final plan = clone(original);
      plan['days'] = [
        for (var i = 0; i < n; i++)
          {
            'id': 'day$i',
            'name': 'Day$i',
            'exercises': [
              {'id': 'slot$i', 'name': 'Custom', 'sets': 1, 'reps': '8'},
            ],
          },
      ];
      plan['custom'] = {'keep': true};
      validatePlan(plan);
      expect(clone(plan)['custom'], {'keep': true});
    }
  });
  test('invalid plan envelope, texts, bounds and identities are rejected', () {
    final mutations = <void Function(Json)>[
      (p) => p['format'] = 'other',
      (p) => p['schemaVersion'] = 2,
      (p) => p['revision'] = 0,
      (p) => p['revision'] = 1.5,
      (p) => p['title'] = ' ',
      (p) => p['title'] = 'x' * 121,
      (p) => p['days'] = [],
      (p) => p['days'] = List.filled(8, daysOf(p)[0]),
      (p) => p['days'] = [1],
      (p) => daysOf(p)[1]['id'] = daysOf(p)[0]['id'],
      (p) => daysOf(p)[0]['name'] = null,
      (p) => daysOf(p)[0]['focus'] = 'x' * 201,
      (p) => daysOf(p)[0]['exercises'] = [],
      (p) => daysOf(p)[0]['exercises'] = List.filled(21, exercisesOf(p, 0)[0]),
      (p) => daysOf(p)[0]['exercises'] = [false],
      (p) => exercisesOf(p, 0)[1]['id'] = exercisesOf(p, 0)[0]['id'],
      (p) => exercisesOf(p, 0)[0]['catalogId'] = '',
      (p) => exercisesOf(p, 0)[0]['sets'] = 0,
      (p) => exercisesOf(p, 0)[0]['sets'] = 11,
      (p) => exercisesOf(p, 0)[0]['sets'] = 2.1,
      (p) => exercisesOf(p, 0)[0]['reps'] = 'x' * 41,
      (p) => exercisesOf(p, 0)[0]['id'] = 'x' * 81,
    ];
    for (final mutation in mutations) {
      final plan = clone(original);
      mutation(plan);
      expect(() => validatePlan(plan), throwsFormatException);
    }
  });
  test('optional measurements keep missing values distinct', () {
    for (final (kg, reps) in [
      ('', ''),
      ('0', ''),
      ('', '8'),
      ('12,5', '10'),
      (' 2 ', ' +3 '),
    ]) {
      validateSet(kg, reps);
    }
    for (final (kg, reps) in [
      ('-1', ''),
      ('NaN', ''),
      ('Infinity', ''),
      ('a', ''),
      ('', '0'),
      ('', '-1'),
      ('', '2.5'),
      ('', 'word'),
      ('', '99999999999999999999999999999999'),
    ]) {
      expect(() => validateSet(kg, reps), throwsFormatException);
    }
    expect(setSummary('', ''), contains('sem carga/repetições'));
    expect(setSummary('', '8'), '8 reps · carga não registrada');
    expect(setSummary('12', ''), '12 kg · repetições não registradas');
    expect(setSummary(' 12 ', ' 8 '), '12 kg × 8');
    final url = executionUrl('Agachamento / braços & pés');
    expect(url.host, 'www.google.com');
    expect(
      url.queryParameters['q'],
      'Agachamento / braços & pés exercício execução correta',
    );
  });
  test('catalog aliases, explicit IDs and legacy slots preserve identity', () {
    expect(catalog.exercises.length, 90);
    final slot = exercisesOf(original, 0)[0], known = catalog.resolve(slot)!;
    expect(catalog.resolve({'name': 'SUPINO RETO BARRA'})?['id'], known['id']);
    expect(
      catalog.resolve({'name': 'Renamed', 'id': slot['id']})?['id'],
      known['id'],
    );
    expect(catalog.resolve({...slot, 'catalogId': 'future'}), null);
    expect(catalog.resolve({'name': 'Custom'}), null);
    expect(catalog.alternatives(null), isEmpty);
    for (final row in catalog.exercises.values) {
      expect(catalog.name(row), isNotEmpty);
      expect(catalog.loadHint(row), isNotEmpty);
      for (final alternative in catalog.alternatives(row)) {
        expect(catalog.similar(row, alternative), true);
        expect(alternative['id'], isNot(row['id']));
      }
    }
    for (final unit in [
      'per-dumbbell',
      'per-side',
      'bodyweight',
      'assistance',
      'band',
      'total',
    ]) {
      expect(catalog.loadHint({'loadUnit': unit}), isNotEmpty);
    }
    expect(() => catalog.label('groups', 'unknown'), throwsFormatException);
    expect(
      catalog.sameExercise(slot, {'id': 'another', 'name': slot['name']}),
      true,
    );
    expect(
      catalog.sameExercise(
        {'id': 'x', 'name': 'Custom'},
        {'id': 'x', 'name': 'Changed'},
      ),
      true,
    );
    expect(
      catalog.sameExercise(
        {'id': 'x', 'name': 'Custom'},
        {'id': 'y', 'name': 'Custom'},
      ),
      false,
    );
    expect(
      catalog.sameExercise({'catalogId': 'future'}, {'catalogId': 'future'}),
      true,
    );
    expect(
      catalog.sameExercise(
        {'catalogId': 'future'},
        {'id': 'x', 'name': 'custom'},
      ),
      false,
    );
  });
  test(
    'catalog rejects invalid references duplicates and ambiguous aliases',
    () {
      for (final mutate in <void Function(Json)>[
        (c) => c['format'] = 'bad',
        (c) => c['schemaVersion'] = 2,
        (c) => c['groups'].add(c['groups'][0]),
        (c) => c['exercises'].add(c['exercises'][0]),
        (c) => c['exercises'][0]['group'] = 'missing',
        (c) => c['exercises'][0]['primaryMuscles'] = [],
        (c) => c['exercises'][0]['equipment'] = [],
        (c) =>
            c['exercises'][1]['aliases'].add(c['exercises'][0]['name']['pt']),
      ]) {
        final data = clone(rawCatalog);
        mutate(data);
        expect(() => Catalog(data, original), throwsFormatException);
      }
    },
  );
  test('swap is session only and blocks all data including hidden sets', () {
    final plan = clone(original),
        slot = exercisesOf(plan, 0)[0],
        known = catalog.resolve(slot)!;
    final target = catalog.alternatives(known).first['id'] as String;
    final draft = <String, dynamic>{};
    catalog.switchTo(plan, 0, 0, draft, target);
    expect(catalog.effective(slot, draft)['catalogId'], target);
    expect(slot['catalogId'], known['id']);
    catalog.validateOverrides(plan, 0, draft);
    expect(
      exercisesOf(catalog.snapshot(plan, 0, draft), 0)[0]['catalogId'],
      target,
    );
    catalog.switchTo(plan, 0, 0, draft, known['id']);
    expect(draft, isEmpty);
    for (final entry in {
      '0_2kg': '5',
      '0_2reps': '8',
      '0_2done': true,
    }.entries) {
      expect(
        () => catalog.switchTo(plan, 0, 0, {entry.key: entry.value}, target),
        throwsFormatException,
      );
    }
    expect(
      () => catalog.switchTo(plan, 0, 0, {}, 'missing'),
      throwsFormatException,
    );
    expect(
      () => catalog.effective(slot, {
        'exerciseOverrides': <String, dynamic>{slot['id']: 'missing'},
      }),
      throwsFormatException,
    );
    for (final overrides in [
      false,
      {'unknown': target},
      <String, dynamic>{slot['id']: 'missing'},
      <String, dynamic>{slot['id']: 'barbell-back-squat'},
    ]) {
      expect(
        () => catalog.validateOverrides(plan, 0, {
          'exerciseOverrides': overrides,
        }),
        throwsFormatException,
      );
    }
  });
  test(
    'cycle advances only expected; extras and explicit position survive',
    () {
      final s = fresh();
      expect(s.selected, 0);
      expect(s.next, 'day-0');
      s.data['day'] = 2;
      s.draft['0_0done'] = true;
      s.finish(catalog, DateTime(2026, 10, 14, 8, 5));
      expect(s.next, 'day-0');
      expect(s.history.single['extra'], true);
      expect(s.history.single['date'], '14/10/2026 08:05');
      expect(s.selected, 0);
      for (var d = 0; d < daysOf(s.plan).length; d++) {
        expect(s.selected, d);
        s.draft['0_0done'] = true;
        s.finish(catalog, DateTime(2026));
      }
      expect(s.next, 'day-0');
      expect(s.history.length, 6);
      expect(() => afterSave(s.plan, 'missing', 0), throwsFormatException);
      expect(workoutLabel(6), 'Treino G');
    },
  );
  test('partial completion validation snapshots and last performance', () {
    final s = fresh();
    expect(() => s.completedCount(), throwsFormatException);
    s.draft.addAll({'0_0done': true, '0_0kg': 'bad'});
    expect(() => s.finish(catalog, DateTime.now()), throwsFormatException);
    expect(s.history, isEmpty);
    s.draft['0_0kg'] = '25';
    s.finish(catalog, DateTime.now());
    final item = exercisesOf(s.plan, 0)[0];
    expect(
      s.lastPerformance(item, catalog),
      '25 kg · repetições não registradas',
    );
    s.data['day'] = 0;
    s.draft['0_0done'] = true;
    s.finish(catalog, DateTime.now());
    expect(
      s.lastPerformance(item, catalog),
      '25 kg · repetições não registradas',
    );
    expect(
      s.lastPerformance({'id': 'missing', 'name': 'Unknown'}, catalog),
      '',
    );
    expect(s.history.last['sets'], {
      '0_0done': true,
      '0_0kg': '',
      '0_0reps': '',
    });
    final recorded = s.history.first['plan'];
    s.plan['title'] = 'changed';
    expect(recorded['title'], isNot('changed'));
    s.data['phase'] = 2;
    expect(s.setCount(item), item['sets']);
    expect(fresh().setCount({'sets': 1}), 1);
  });
  test('legacy migration binds original snapshots and opaque cursor IDs', () {
    final s = migrateLegacy(
      {
        'history': jsonEncode([
          {'date': 'old', 'day': 1, 'phase': 0, 'sets': {}},
        ]),
        'day': 0,
      },
      original,
      catalog,
    );
    expect(s.next, 'day-2');
    expect(s.history.first['plan'], original);
    final p = clone(original);
    p['days'][0]['id'] = 'a\u0000\r\n\u0001é"';
    for (final value in [
      jsonEncode([workoutId(p, 0)]),
      workoutId(p, 0),
    ]) {
      final migrated = migrateLegacy(
        {
          'plan': jsonEncode(p),
          'nextWorkoutId': value,
          'day': 1,
          'draft1': '{"0_0kg":"7"}',
          'planUrl': 'https://example.com/plan',
        },
        original,
        catalog,
      );
      expect(migrated.next, workoutId(p, 0));
      expect(migrated.selected, 1);
      expect(migrated.draft['0_0kg'], '7');
      expect(migrated.planUrl, 'https://example.com/plan');
      expect(
        restoreBackup(migrated.backup(), original, catalog).next,
        migrated.next,
      );
    }
    expect(
      migrateLegacy(
        {'day': 99, 'nextWorkoutId': '[]'},
        original,
        catalog,
      ).selected,
      0,
    );
  });
  test(
    'cursor migration skips unrelated records and respects saved successor',
    () {
      final p = clone(original), old = clone(original);
      old['days'][0]['id'] = 'removed';
      expect(
        migrateCursor(p, [
          false,
          {},
          {'plan': old, 'day': 99},
          {'plan': old, 'day': 0},
        ], 3),
        'day-3',
      );
      expect(
        migrateCursor(p, [
          {'plan': p, 'day': 1, 'nextWorkoutId': 'day-4'},
        ], 0),
        'day-4',
      );
      expect(
        migrateCursor(p, [
          {'plan': p, 'day': 1, 'nextWorkoutId': 'gone'},
        ], 0),
        'day-2',
      );
      expect(migrateCursor(p, [], -1), 'day-0');
      expect(migrateCursor(p, [], 99), 'day-0');
    },
  );
  test('backup versions 1 through 4 remain portable and exclude URL', () {
    final s = fresh();
    s.data['planUrl'] = 'https://private.example';
    s.draft['0_0kg'] = '12,5';
    s.data['day'] = 2;
    s.data['nextWorkoutId'] = 'day-3';
    for (var version = 1; version <= 4; version++) {
      final backup = s.backup()..['version'] = version;
      if (version == 1) backup.remove('plan');
      expect(backup.containsKey('planUrl'), false);
      final restored = restoreBackup(
        backup,
        original,
        catalog,
        planUrl: 'https://local',
      );
      expect(restored.draftAt(0)['0_0kg'], '12,5');
      expect(restored.planUrl, 'https://local');
      expect(restored.selected, version == 4 ? 2 : 0);
      expect(restored.next, version == 4 ? 'day-3' : 'day-0');
    }
    final restored = restoreBackup(s.backup(), original, catalog)..resume();
    expect(restored.selected, 3);
  });
  test('backup validates full structure and fails without mutation', () {
    final initial = fresh().backup();
    for (final mutate in <void Function(Json)>[
      (b) => b['version'] = 5,
      (b) => b['version'] = '4',
      (b) => b['plan'] = false,
      (b) => b['phase'] = 3,
      (b) => b['phase'] = -1,
      (b) => b['phase'] = '0',
      (b) => b['history'] = false,
      (b) => b['history'] = [false],
      (b) => b['history'] = [
        {'plan': false},
      ],
      (b) => b['history'] = [
        {'date': 'x', 'day': -1, 'sets': {}},
      ],
      (b) => b['history'] = [
        {'date': 1, 'day': 0, 'sets': {}},
      ],
      (b) => b['history'] = [
        {'date': 'x', 'day': 0, 'sets': false},
      ],
      (b) => b.remove('draft0'),
      (b) => b['draft0'] = {'other': 'x'},
      (b) => b['draft0'] = {'0_0done': 'true'},
      (b) => b['draft0'] = {'0_0kg': 1},
      (b) => b['draft0'] = {'exerciseOverrides': false},
      (b) => b['nextWorkoutId'] = 'missing',
      (b) => b['nextWorkoutId'] = 1,
      (b) => b['day'] = -1,
      (b) => b['day'] = 99,
      (b) => b['day'] = '0',
    ]) {
      final backup = clone(initial);
      mutate(backup);
      expect(
        () => restoreBackup(backup, original, catalog),
        throwsFormatException,
      );
      expect(initial, fresh().backup());
    }
  });
  test('revisions preserve surviving cursor while new plans reset and drafts block', () {
    final s = fresh();
    s.data['nextWorkoutId'] = 'day-2';
    final revised = clone(original)..['revision'] = 2;
    revised['days'] = (revised['days'] as List).reversed.toList();
    expect(s.applyPlan(revised), false);
    expect(s.next, 'day-2');
    expect(s.selected, 2);
    final removed = clone(revised)..['revision'] = 3;
    removed['days'] = (removed['days'] as List)
        .where((d) => d['id'] != 'day-2')
        .toList();
    expect(s.applyPlan(removed, revision: true), true);
    expect(s.next, workoutId(removed, 0));
    final unrelated = clone(original)..['revision'] = 4;
    for (final day in daysOf(unrelated)) {
      day['id'] = 'new${day['id']}';
    }
    expect(relatedPlans(s.plan, unrelated), false);
    expect(s.applyPlan(unrelated), true);
    s.draft['0_0done'] = false;
    expect(s.hasDrafts, true);
    expect(() => s.applyPlan(original), throwsFormatException);
  });
  test('links validate destination version raw encoding and strict UTF8', () {
    final link = encodeWorkoutLink(original);
    expect(parseWorkoutLink(link), original);
    expect(parseWorkoutLink(link.replaceFirst(webBase, appBase)), original);
    for (final address in [
      '',
      'x' * 64001,
      link.replaceFirst('https:', 'http:'),
      link.replaceFirst('william-gr.github.io', 'evil.example'),
      link.replaceFirst('/open/', '/open'),
      link.replaceFirst('github.io/', 'github.io:443/'),
      link.replaceFirst('https://', 'https://user@'),
      link.replaceFirst('#', '?x=1#'),
      '$webBase#v2.abc',
      '$webBase#v1.',
      '$webBase#v1.%61',
      '$webBase#v1.a=',
      '$webBase#v1._w',
      '$webBase#v1.${base64Url.encode(utf8.encode('{}')).replaceAll('=', '')}',
    ]) {
      expect(
        () => parseWorkoutLink(address),
        throwsA(anything),
        reason: address.substring(0, address.length.clamp(0, 100)),
      );
    }
    final huge = clone(original)..['metadata'] = 'x' * 64000;
    expect(() => encodeWorkoutLink(huge), throwsFormatException);
  });
  test('short and review ChatGPT prompts strip all private metadata', () {
    final p = clone(original)..['history'] = 'secret-history';
    p['private'] = 'secret-top';
    daysOf(p)[0]['secret'] = 'secret-day';
    exercisesOf(p, 0)[0]['secret'] = 'secret-ex';
    final short = chatPrompt(p, false), review = chatPrompt(p, true);
    expect(short.length, lessThan(1000));
    expect(short, contains(guideUrl));
    expect(short, contains('A/B/C'));
    expect(short, isNot(contains('Supino')));
    expect(review, contains('Supino'));
    expect(review, isNot(contains('secret')));
    expect(review, isNot(contains('primaryMuscles')));
  });
}
