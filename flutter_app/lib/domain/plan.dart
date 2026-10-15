import 'dart:convert';

typedef Json = Map<String, dynamic>;
Json clone(Json value) => jsonDecode(jsonEncode(value)) as Json;
Never invalid(String message) => throw FormatException(message);
void bounded(dynamic value, int limit) {
  if (value is! String || value.trim().isEmpty || value.length > limit) {
    invalid('Texto vazio ou muito longo');
  }
}

void validatePlan(Json plan) {
  if (plan['format'] != 'meu-treino-plan' || plan['schemaVersion'] != 1) {
    invalid('Formato incompatível');
  }
  if (plan['revision'] is! int || plan['revision'] < 1) {
    invalid('Revisão inválida');
  }
  bounded(plan['title'], 120);
  final days = plan['days'];
  if (days is! List || days.isEmpty || days.length > 7) {
    invalid('Use entre 1 e 7 treinos');
  }
  final dayIds = <String>{}, exerciseIds = <String>{};
  for (final dynamic day in days) {
    if (day is! Json) invalid('Treino inválido');
    bounded(day['id'], 80);
    if (!dayIds.add(day['id'])) invalid('Treinos duplicados');
    bounded(day['name'], 80);
    if (day.containsKey('focus')) bounded(day['focus'], 200);
    final exercises = day['exercises'];
    if (exercises is! List || exercises.isEmpty || exercises.length > 20) {
      invalid('Use entre 1 e 20 exercícios');
    }
    for (final dynamic item in exercises) {
      if (item is! Json) invalid('Exercício inválido');
      bounded(item['id'], 80);
      if (!exerciseIds.add(item['id'])) invalid('IDs de exercícios duplicados');
      bounded(item['name'], 120);
      if (item.containsKey('catalogId')) bounded(item['catalogId'], 80);
      bounded(item['reps'], 40);
      if (item['sets'] is! int || item['sets'] < 1 || item['sets'] > 10) {
        invalid('Use entre 1 e 10 séries');
      }
    }
  }
}

List<Json> daysOf(Json plan) => (plan['days'] as List).cast<Json>();
List<Json> exercisesOf(Json plan, int day) =>
    (daysOf(plan)[day]['exercises'] as List).cast<Json>();
String workoutId(Json plan, int day) => daysOf(plan)[day]['id'] as String;
String workoutLabel(int day) => 'Treino ${String.fromCharCode(65 + day)}';
int workoutIndex(Json plan, String id) =>
    daysOf(plan).indexWhere((day) => day['id'] == id);
String afterSave(Json plan, String next, int completed) {
  final expected = workoutIndex(plan, next);
  if (expected < 0) invalid('Próximo treino inválido');
  return expected == completed
      ? workoutId(plan, (completed + 1) % daysOf(plan).length)
      : next;
}

String revisedCursor(Json plan, String next) =>
    workoutIndex(plan, next) >= 0 ? next : workoutId(plan, 0);
bool relatedPlans(Json a, Json b) =>
    daysOf(a).any((day) => workoutIndex(b, day['id']) >= 0);
String migrateCursor(Json plan, List history, int selected) {
  for (final dynamic record in history.reversed) {
    if (record is! Json || record['plan'] is! Json || record['day'] is! int) {
      continue;
    }
    final old = record['plan'] as Json, day = record['day'] as int;
    if (day < 0 || day >= daysOf(old).length) continue;
    final completed = workoutIndex(plan, workoutId(old, day));
    if (completed < 0) continue;
    final next = record['nextWorkoutId'];
    if (next is String && workoutIndex(plan, next) >= 0) return next;
    return workoutId(plan, (completed + 1) % daysOf(plan).length);
  }
  return workoutId(
    plan,
    selected >= 0 && selected < daysOf(plan).length ? selected : 0,
  );
}

void validateSet(String kg, String reps) {
  kg = kg.trim();
  reps = reps.trim();
  if (kg.isNotEmpty) {
    final weight = double.tryParse(kg.replaceAll(',', '.'));
    if (weight == null || !weight.isFinite || weight < 0) {
      invalid('Carga inválida');
    }
  }
  if (reps.isNotEmpty &&
      (!RegExp(r'^\+?\d+$').hasMatch(reps) || (int.tryParse(reps) ?? 0) <= 0)) {
    invalid('Repetições inválidas');
  }
}

String setSummary(String kg, String reps) {
  kg = kg.trim();
  reps = reps.trim();
  if (kg.isEmpty && reps.isEmpty) {
    return 'Série concluída · sem carga/repetições registradas';
  }
  if (kg.isEmpty) return '$reps reps · carga não registrada';
  if (reps.isEmpty) return '$kg kg · repetições não registradas';
  return '$kg kg × $reps';
}

Uri executionUrl(String name) => Uri.https('www.google.com', '/search', {
  'q': '$name exercício execução correta',
});
