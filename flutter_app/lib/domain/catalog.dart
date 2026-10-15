import 'package:diacritic/diacritic.dart';

import 'plan.dart';

class Catalog {
  final Map<String, Json> exercises = {};
  final Map<String, String> aliases = {}, legacySlots = {};
  final Map<String, Map<String, String>> terms = {};
  Catalog(Json data, Json original) {
    if (data['format'] != 'setharbor-exercise-catalog' ||
        data['schemaVersion'] != 1) {
      invalid('Catálogo incompatível');
    }
    for (final table in [
      'groups',
      'muscles',
      'equipment',
      'movementPatterns',
      'substitutionFamilies',
    ]) {
      final entries = <String, String>{};
      for (final row in data[table]) {
        if (entries.containsKey(row['id'])) invalid('Termo duplicado');
        entries[row['id']] = row['name']['pt'];
      }
      terms[table] = entries;
    }
    for (final Json row in (data['exercises'] as List).cast<Json>()) {
      final id = row['id'] as String;
      if (exercises.containsKey(id)) invalid('Exercício duplicado');
      exercises[id] = row;
      for (final field in ['group', 'movementPattern', 'substitutionFamily']) {
        label(
          {
            'group': 'groups',
            'movementPattern': 'movementPatterns',
            'substitutionFamily': 'substitutionFamilies',
          }[field]!,
          row[field],
        );
      }
      for (final field in [
        'primaryMuscles',
        'secondaryMuscles',
        'stabilizerMuscles',
        'equipment',
      ]) {
        final refs = row[field] as List;
        if ((field == 'primaryMuscles' || field == 'equipment') &&
            refs.isEmpty) {
          invalid('Referência vazia');
        }
        labels(field == 'equipment' ? 'equipment' : 'muscles', refs);
      }
      for (final name in [
        row['name']['pt'],
        row['name']['en'],
        ...row['aliases'],
      ]) {
        final key = normalize(name);
        if (aliases.containsKey(key) && aliases[key] != id) {
          invalid('Nome ambíguo');
        }
        aliases[key] = id;
      }
    }
    for (var day = 0; day < daysOf(original).length; day++) {
      for (final item in exercisesOf(original, day)) {
        legacySlots[item['id']] = item['catalogId'];
      }
    }
  }
  static String normalize(String value) =>
      removeDiacritics(value.toLowerCase()).trim();
  Json? resolve(Json item) =>
      exercises[item.containsKey('catalogId')
          ? item['catalogId']
          : aliases[normalize(item['name'] ?? '')] ?? legacySlots[item['id']]];
  String label(String table, String id) =>
      terms[table]?[id] ?? invalid('Referência desconhecida: $id');
  String labels(String table, List ids) =>
      ids.map((id) => label(table, id)).join(', ');
  String name(Json item) => item['name']['pt'];
  bool similar(Json a, Json b) => [
    'group',
    'substitutionFamily',
    'movementPattern',
    'mechanic',
  ].every((key) => a[key] == b[key]);
  List<Json> alternatives(Json? current) => current == null
      ? []
      : exercises.values
            .where(
              (item) =>
                  item['id'] != current['id'] &&
                  similar(current, item) &&
                  item['loadUnit'] != 'band' &&
                  item['mechanic'] != 'isometric',
            )
            .toList();
  String loadHint(Json item) => switch (item['loadUnit']) {
    'per-dumbbell' => 'Carga por halter',
    'per-side' => 'Carga por lado',
    'bodyweight' => '0 kg sem carga adicional',
    'assistance' => 'Assistência em kg · reduza para progredir',
    'band' => 'Resistência de elástico',
    _ => 'Carga total em kg',
  };
  Json effective(Json planned, Json draft) {
    final item = clone(planned),
        overrides = draft['exerciseOverrides'] as Json? ?? {};
    if (!overrides.containsKey(planned['id'])) {
      final known = resolve(planned);
      if (known != null) item['catalogId'] = known['id'];
    } else {
      final actual =
          exercises[overrides[planned['id']]] ??
          invalid('Exercício desconhecido');
      item['catalogId'] = actual['id'];
      item['name'] = name(actual);
    }
    return item;
  }

  bool sameExercise(Json a, Json b) {
    final ca = resolve(a), cb = resolve(b);
    if (ca != null && cb != null) return ca['id'] == cb['id'];
    if (a.containsKey('catalogId') || b.containsKey('catalogId')) {
      return a['catalogId'] == b['catalogId'];
    }
    return a['id'] == b['id'];
  }

  void switchTo(Json plan, int day, int exercise, Json draft, String target) {
    final planned = exercisesOf(plan, day)[exercise];
    if (hasExerciseData(draft, exercise, planned['sets'])) {
      invalid('Apague os dados deste exercício antes de trocar.');
    }
    final current = resolve(effective(planned, draft)),
        actual = exercises[target];
    if (actual == null || !alternatives(current).contains(actual)) {
      invalid('Sem alternativa compatível');
    }
    final overrides =
        draft['exerciseOverrides'] as Json? ?? <String, dynamic>{};
    if (resolve(planned)?['id'] == target) {
      overrides.remove(planned['id']);
    } else {
      overrides[planned['id']] = target;
    }
    if (overrides.isEmpty) {
      draft.remove('exerciseOverrides');
    } else {
      draft['exerciseOverrides'] = overrides;
    }
  }

  Json snapshot(Json plan, int day, Json draft) {
    final result = clone(plan), items = exercisesOf(result, day);
    for (var i = 0; i < items.length; i++) {
      items[i] = effective(items[i], draft);
    }
    return result;
  }

  void validateOverrides(Json plan, int day, Json draft) {
    if (!draft.containsKey('exerciseOverrides')) return;
    final overrides = draft['exerciseOverrides'];
    if (overrides is! Json) invalid('Trocas inválidas');
    final items = exercisesOf(plan, day);
    for (final entry in overrides.entries) {
      final slots = items.where((item) => item['id'] == entry.key);
      if (slots.isEmpty) invalid('Posição desconhecida no backup');
      final original = resolve(slots.first), actual = exercises[entry.value];
      if (original == null || actual == null || !similar(original, actual)) {
        invalid('Troca incompatível no backup');
      }
    }
  }
}

bool hasExerciseData(Json draft, int exercise, int sets) {
  for (var s = 0; s < sets; s++) {
    final key = '${exercise}_$s';
    if ((draft['${key}kg'] ?? '').toString().trim().isNotEmpty ||
        (draft['${key}reps'] ?? '').toString().trim().isNotEmpty ||
        draft['${key}done'] == true) {
      return true;
    }
  }
  return false;
}
