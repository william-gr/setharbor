import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform_gateway.dart';
import '../domain/catalog.dart';
import '../domain/plan.dart';
import '../domain/workout_state.dart';

final platformProvider = Provider<PlatformGateway>((ref) => PlatformGateway());
final assetsProvider = FutureProvider<({Json original, Catalog catalog})>((
  ref,
) async {
  final original = jsonDecode(
    await rootBundle.loadString('assets/default-plan.json'),
  ) as Json;
  final data = jsonDecode(
    await rootBundle.loadString('assets/exercise-catalog.json'),
  ) as Json;
  return (original: original, catalog: Catalog(data, original));
});
final workoutProvider = AsyncNotifierProvider<WorkoutController, WorkoutState>(
  WorkoutController.new,
  retry: (count, error) => null,
);

class WorkoutController extends AsyncNotifier<WorkoutState> {
  late Json original;
  late Catalog catalog;
  late PlatformGateway platform;
  Future<void> _tail = Future.value();
  @override
  Future<WorkoutState> build() async {
    final assets = await ref.watch(assetsProvider.future);
    original = assets.original;
    catalog = assets.catalog;
    platform = ref.read(platformProvider);
    final stored = await platform.readState();
    final loaded = stored == null
        ? migrateLegacy(
            jsonDecode(await platform.readLegacy()) as Json,
            original,
            catalog,
          )
        : restoreBackup(
            jsonDecode(stored) as Json,
            original,
            catalog,
            planUrl: (jsonDecode(stored) as Json)['planUrl'] ?? '',
          );
    loaded.resume();
    // Migration succeeds only after durable write; original preferences are untouched.
    await platform.writeState(jsonEncode(loaded.data));
    return loaded;
  }

  /// Serialize keystrokes, selection and save into durable whole-state commits.
  /// Never publish a failed write or let a failed transaction poison the queue.
  Future<T> transact<T>(T Function(WorkoutState) change) {
    final operation = _tail.then((_) async {
      final changed = state.requireValue.copy();
      final result = change(changed);
      await platform.writeState(jsonEncode(changed.data));
      state = AsyncData(changed);
      return result;
    });
    _tail = operation.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return operation;
  }

  Future<void> select(int day) => transact((s) {
    if (day < 0 || day >= daysOf(s.plan).length) invalid('Treino inválido');
    s.data['day'] = day;
  });
  Future<void> setPhase(int phase) => transact((s) {
    if (phase < 0 || phase > 2) invalid('Modo inválido');
    s.data['phase'] = phase;
  });
  Future<void> edit(int day, String key, Object value) => transact((s) {
    s.draftAt(day)[key] = value;
  });
  Future<void> defineNext() => transact((s) {
    s.data['nextWorkoutId'] = workoutId(s.plan, s.selected);
  });
  Future<void> switchExercise(int exercise) => transact((s) {
    final item = catalog.effective(
      exercisesOf(s.plan, s.selected)[exercise],
      s.draft,
    );
    final alternatives = catalog.alternatives(catalog.resolve(item));
    if (alternatives.isEmpty) {
      invalid('Nenhuma alternativa similar disponível.');
    }
    catalog.switchTo(
      s.plan,
      s.selected,
      exercise,
      s.draft,
      alternatives[Random().nextInt(alternatives.length)]['id'],
    );
  });
  Future<void> finish() => transact((s) => s.finish(catalog, DateTime.now()));
  Future<bool> applyPlan(Json plan, {bool? revision}) =>
      transact((s) => s.applyPlan(plan, revision: revision));
  Future<void> restore(Json backup) => transact((s) {
    final restored = restoreBackup(
      backup,
      original,
      catalog,
      planUrl: s.planUrl,
    )..resume();
    s.data.clear();
    s.data.addAll(restored.data);
  });
  Future<void> configureUrl(String url) => transact((s) {
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        invalid('Informe uma URL HTTPS válida.');
      }
    }
    s.data['planUrl'] = url;
  });
  bool linkPending = false, _syncing = false;
  Future<String> sync() async {
    await _tail;
    final url = state.requireValue.planUrl;
    if (url.isEmpty || _syncing) return '';
    _syncing = true;
    try {
      final fetched = jsonDecode(await platform.fetchPlan(url)) as Json;
      validatePlan(fetched);
      return await transact((s) {
        if (linkPending || s.planUrl != url) return '';
        if (fetched['revision'] <= s.plan['revision']) {
          return 'Sua ficha já está atualizada.';
        }
        final reset = s.applyPlan(fetched, revision: true);
        return 'Ficha atualizada. ${reset ? 'Sequência reiniciada no treino A. ' : ''}Histórico preservado.';
      });
    } finally {
      _syncing = false;
    }
  }

  Future<void> flush() => _tail;
}
