import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setharbor/application/workout_controller.dart';
import 'package:setharbor/data/platform_gateway.dart';
import 'package:setharbor/domain/catalog.dart';
import 'package:setharbor/domain/plan.dart';

class MemoryPlatform extends PlatformGateway {
  String? disk;
  String legacy = '{}', fetched = '{}';
  bool fail = false;
  Completer<String>? response;
  @override
  Future<String?> readState() async => disk;
  @override
  Future<String> readLegacy() async => legacy;
  @override
  Future<void> writeState(String json) async {
    if (fail) throw StateError('disk');
    await Future<void>.delayed(Duration.zero);
    disk = json;
  }

  @override
  Future<String> fetchPlan(String url) async =>
      response == null ? fetched : await response!.future;
}

void main() {
  late MemoryPlatform platform;
  late ProviderContainer container;
  late Json original;
  late Catalog catalog;
  setUp(() {
    original =
        jsonDecode(File('assets/default-plan.json').readAsStringSync()) as Json;
    catalog = Catalog(
      jsonDecode(File('assets/exercise-catalog.json').readAsStringSync())
          as Json,
      original,
    );
    platform = MemoryPlatform();
    container = ProviderContainer(
      overrides: [
        platformProvider.overrideWithValue(platform),
        assetsProvider.overrideWith(
          (ref) async => (original: original, catalog: catalog),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());
  test('serialized edits, save and restart preserve all data', () async {
    await container.read(workoutProvider.future);
    final c = container.read(workoutProvider.notifier);
    await Future.wait([
      c.edit(0, '0_0kg', '12'),
      c.edit(0, '0_0reps', '8'),
      c.edit(0, '0_0done', true),
    ]);
    await c.finish();
    final saved = container.read(workoutProvider).requireValue;
    expect(saved.history.single['sets']['0_0kg'], '12');
    expect(saved.next, 'day-1');
    expect(saved.draftAt(0), isEmpty);
    container.invalidate(workoutProvider);
    final restored = await container.read(workoutProvider.future);
    expect(restored.next, 'day-1');
    expect(restored.history.length, 1);
  });
  test(
    'failed atomic save keeps draft history cursor and queue usable',
    () async {
      await container.read(workoutProvider.future);
      final c = container.read(workoutProvider.notifier);
      await c.edit(0, '0_0done', true);
      final before = platform.disk;
      platform.fail = true;
      await expectLater(c.finish(), throwsStateError);
      expect(platform.disk, before);
      expect(
        container.read(workoutProvider).requireValue.draft['0_0done'],
        true,
      );
      expect(container.read(workoutProvider).requireValue.history, isEmpty);
      platform.fail = false;
      await c.finish();
      expect(container.read(workoutProvider).requireValue.next, 'day-1');
    },
  );
  test('migration failure and corrupt state never reset storage', () async {
    platform.legacy = 'not JSON';
    await expectLater(
      container.read(workoutProvider.future),
      throwsFormatException,
    );
    expect(platform.disk, null);
    container.invalidate(workoutProvider);
    platform.legacy = '{}';
    platform.fail = true;
    await expectLater(container.read(workoutProvider.future), throwsStateError);
    expect(platform.disk, null);
    container.invalidate(workoutProvider);
    platform.fail = false;
    platform.disk = 'broken';
    await expectLater(
      container.read(workoutProvider.future),
      throwsFormatException,
    );
    expect(platform.disk, 'broken');
  });
  test(
    'selection phases next position swap backup and invalid inputs',
    () async {
      await container.read(workoutProvider.future);
      final c = container.read(workoutProvider.notifier);
      await c.select(2);
      await c.defineNext();
      expect(container.read(workoutProvider).requireValue.next, 'day-2');
      await c.setPhase(2);
      expect(container.read(workoutProvider).requireValue.phase, 2);
      await expectLater(c.select(-1), throwsFormatException);
      await expectLater(c.select(99), throwsFormatException);
      await expectLater(c.setPhase(-1), throwsFormatException);
      await expectLater(c.setPhase(3), throwsFormatException);
      await c.select(0);
      await c.switchExercise(0);
      final s = container.read(workoutProvider).requireValue;
      expect(s.draft['exerciseOverrides'], isNotEmpty);
      final backup = s.backup();
      await c.restore(backup);
      expect(
        container.read(workoutProvider).requireValue.draft,
        backup['draft0'],
      );
      await c.edit(0, '0_0done', true);
      await expectLater(c.switchExercise(0), throwsFormatException);
    },
  );
  test(
    'new plan and HTTPS revision rules protect drafts and pending links',
    () async {
      await container.read(workoutProvider.future);
      final c = container.read(workoutProvider.notifier);
      final revised = clone(original)..['revision'] = 2;
      await expectLater(
        c.configureUrl('http://example.com'),
        throwsFormatException,
      );
      await expectLater(c.configureUrl('https:///'), throwsFormatException);
      await expectLater(
        c.configureUrl('https://user@example.com'),
        throwsFormatException,
      );
      expect(await c.sync(), '');
      await c.configureUrl('https://example.com/plan');
      platform.fetched = jsonEncode(revised);
      c.linkPending = true;
      expect(await c.sync(), '');
      expect(container.read(workoutProvider).requireValue.plan['revision'], 1);
      c.linkPending = false;
      expect(await c.sync(), contains('Ficha atualizada'));
      expect(await c.sync(), contains('já está atualizada'));
      await c.edit(0, '0_0kg', '4');
      platform.fetched = jsonEncode(clone(revised)..['revision'] = 3);
      await expectLater(c.sync(), throwsFormatException);
      expect(container.read(workoutProvider).requireValue.plan['revision'], 2);
      platform.fetched = 'broken';
      await expectLater(c.sync(), throwsFormatException);
      await c.configureUrl('');
      expect(await c.sync(), '');
    },
  );
  test(
    'inflight HTTPS cannot overwrite replaced URL or a newer plan',
    () async {
      await container.read(workoutProvider.future);
      final c = container.read(workoutProvider.notifier);
      await c.configureUrl('https://example.com/old');
      platform.response = Completer<String>();
      final pending = c.sync();
      await Future<void>.delayed(Duration.zero);
      expect(await c.sync(), '');
      await c.configureUrl('https://example.com/new');
      platform.response!.complete(
        jsonEncode(clone(original)..['revision'] = 2),
      );
      expect(await pending, '');
      final s = container.read(workoutProvider).requireValue;
      expect(s.plan['revision'], 1);
      expect(await c.applyPlan(clone(original)..['revision'] = 2), false);
    },
  );
}
