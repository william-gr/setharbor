import 'dart:convert';

import 'catalog.dart';
import 'plan.dart';

/// Backup v4 is also the durable Flutter state; planUrl remains local only.
class WorkoutState {
  final Json data;
  WorkoutState(this.data);
  Json get plan => data['plan'];
  List<Json> get history => (data['history'] as List).cast<Json>();
  int get selected => data['day'];
  int get phase => data['phase'];
  String get next => data['nextWorkoutId'];
  int get nextIndex => workoutIndex(plan, next);
  String get planUrl => data['planUrl'] ?? '';
  Json draftAt(int day) => data['draft$day'] as Json;
  Json get draft => draftAt(selected);
  bool get hasDrafts => List.generate(
    daysOf(plan).length,
    draftAt,
  ).any((value) => value.isNotEmpty);
  WorkoutState copy() => WorkoutState(clone(data));
  Json backup() {
    final result = clone(data);
    result.remove('planUrl');
    return result;
  }

  void resume() {
    if (draft.isEmpty) data['day'] = nextIndex;
  }

  int setCount(Json item) => phase == 0 && item['sets'] > 2 ? 2 : item['sets'];
  int completedCount() {
    var count = 0;
    final exercises = exercisesOf(plan, selected);
    for (var e = 0; e < exercises.length; e++) {
      for (var s = 0; s < setCount(exercises[e]); s++) {
        final key = '${e}_$s';
        if (draft['${key}done'] != true) continue;
        validateSet(draft['${key}kg'] ?? '', draft['${key}reps'] ?? '');
        count++;
      }
    }
    if (count == 0) invalid('Marque ao menos uma série feita para salvar.');
    return count;
  }

  void finish(Catalog catalog, DateTime now) {
    completedCount();
    final sets = <String, dynamic>{}, items = exercisesOf(plan, selected);
    for (var e = 0; e < items.length; e++) {
      for (var s = 0; s < setCount(items[e]); s++) {
        final key = '${e}_$s';
        if (draft['${key}done'] == true) {
          sets['${key}done'] = true;
          sets['${key}kg'] = draft['${key}kg'] ?? '';
          sets['${key}reps'] = draft['${key}reps'] ?? '';
        }
      }
    }
    final advanced = afterSave(plan, next, selected);
    String two(int n) => n.toString().padLeft(2, '0');
    history.add({
      'date':
          '${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}',
      'day': selected,
      'phase': phase,
      'sets': sets,
      'plan': catalog.snapshot(plan, selected, draft),
      'workoutId': workoutId(plan, selected),
      'workoutLabel': workoutLabel(selected),
      'extra': selected != nextIndex,
      'nextWorkoutId': advanced,
    });
    data['draft$selected'] = <String, dynamic>{};
    data['nextWorkoutId'] = advanced;
    data['day'] = workoutIndex(plan, advanced);
  }

  bool applyPlan(Json revised, {bool? revision}) {
    validatePlan(revised);
    if (hasDrafts) {
      invalid(
        'Conclua os treinos em andamento antes de trocar a ficha. Seus registros foram mantidos.',
      );
    }
    revision ??=
        revised['revision'] > plan['revision'] && relatedPlans(plan, revised);
    final cursor = revision
        ? revisedCursor(revised, next)
        : workoutId(revised, 0);
    final reset = !revision || cursor != next;
    data['plan'] = clone(revised);
    data['nextWorkoutId'] = cursor;
    data['day'] = workoutIndex(revised, cursor);
    for (var d = 0; d < 7; d++) {
      data.remove('draft$d');
    }
    for (var d = 0; d < daysOf(revised).length; d++) {
      data['draft$d'] = <String, dynamic>{};
    }
    return reset;
  }

  String lastPerformance(Json current, Catalog catalog) {
    for (final record in history.reversed) {
      final old = record['plan'] as Json, values = record['sets'] as Json;
      final items = exercisesOf(old, record['day']);
      for (var e = 0; e < items.length; e++) {
        if (!catalog.sameExercise(current, items[e])) continue;
        final parts = <String>[];
        for (var s = 0; s < items[e]['sets']; s++) {
          final key = '${e}_$s',
              kg = (values['${key}kg'] ?? '') as String,
              reps = (values['${key}reps'] ?? '') as String;
          if (values['${key}done'] == true &&
              (kg.trim().isNotEmpty || reps.trim().isNotEmpty)) {
            parts.add(setSummary(kg, reps));
          }
        }
        if (parts.isNotEmpty) return parts.join(' / ');
      }
    }
    return '';
  }
}

void validateDraft(Json draft) {
  for (final entry in draft.entries) {
    if (entry.key == 'exerciseOverrides') continue;
    if (!RegExp(r'^\d+_\d+(kg|reps|done)$').hasMatch(entry.key)) {
      invalid('Campo de série desconhecido');
    }
    if (entry.key.endsWith('done')
        ? entry.value is! bool
        : entry.value is! String) {
      invalid('Valor de série inválido');
    }
  }
}

WorkoutState restoreBackup(
  Json backup,
  Json original,
  Catalog catalog, {
  String planUrl = '',
}) {
  final version = backup['version'];
  if (version is! int || version < 1 || version > 4) {
    invalid('Backup incompatível');
  }
  final plan = version >= 2 ? backup['plan'] : clone(original);
  if (plan is! Json) invalid('Ficha ausente');
  validatePlan(plan);
  final phase = backup['phase'];
  if (phase is! int || phase < 0 || phase > 2) invalid('Modo inválido');
  final history = backup['history'];
  if (history is! List) invalid('Histórico inválido');
  final data = clone(backup)..remove('planUrl');
  data['history'] = jsonDecode(jsonEncode(history));
  for (final dynamic record in data['history']) {
    if (record is! Json) invalid('Sessão inválida');
    final old = record['plan'] ?? clone(original);
    if (old is! Json) invalid('Snapshot inválido');
    validatePlan(old);
    record['plan'] = old;
    final day = record['day'];
    if (day is! int ||
        day < 0 ||
        day >= daysOf(old).length ||
        record['date'] is! String ||
        record['sets'] is! Json) {
      invalid('Sessão inválida');
    }
    validateDraft(record['sets']);
  }
  for (var d = 0; d < daysOf(plan).length; d++) {
    final draft = data['draft$d'];
    if (draft is! Json) invalid('Rascunho ausente');
    validateDraft(draft);
    catalog.validateOverrides(plan, d, draft);
  }
  final next = version == 4
      ? backup['nextWorkoutId']
      : migrateCursor(plan, data['history'], 0);
  final selected = version == 4 ? backup['day'] : 0;
  if (next is! String ||
      workoutIndex(plan, next) < 0 ||
      selected is! int ||
      selected < 0 ||
      selected >= daysOf(plan).length) {
    invalid('Sequência inválida');
  }
  // Only the state contract is persisted; unknown plan metadata stays in plan.
  return WorkoutState({
    'version': 4,
    'plan': clone(plan),
    'history': data['history'],
    'phase': phase,
    'nextWorkoutId': next,
    'day': selected,
    'planUrl': planUrl,
    for (var d = 0; d < daysOf(plan).length; d++) 'draft$d': data['draft$d'],
  });
}

WorkoutState migrateLegacy(Json prefs, Json original, Catalog catalog) {
  final plan = prefs.containsKey('plan')
      ? jsonDecode(prefs['plan']) as Json
      : clone(original);
  validatePlan(plan);
  final history = jsonDecode(prefs['history'] ?? '[]') as List;
  for (final dynamic record in history) {
    if (record is Json) record.putIfAbsent('plan', () => clone(original));
  }
  final selection =
      prefs['day'] is int &&
          prefs['day'] >= 0 &&
          prefs['day'] < daysOf(plan).length
      ? prefs['day'] as int
      : 0;
  final stored = prefs['nextWorkoutId'] as String? ?? '';
  var next = stored;
  try {
    final decoded = jsonDecode(stored);
    if (decoded is List && decoded.length == 1 && decoded.first is String) {
      next = decoded.first;
    }
  } on FormatException {
    /* Older local builds stored a plain identifier. */
  }
  if (workoutIndex(plan, next) < 0) {
    next = migrateCursor(plan, history, selection);
  }
  final backup = <String, dynamic>{
    'version': 4,
    'plan': plan,
    'history': history,
    'phase': prefs['phase'] ?? 0,
    'day': selection,
    'nextWorkoutId': next,
    for (var d = 0; d < daysOf(plan).length; d++)
      'draft$d': jsonDecode(prefs['draft$d'] ?? '{}'),
  };
  return restoreBackup(
    backup,
    original,
    catalog,
    planUrl: prefs['planUrl'] ?? '',
  )..resume();
}
