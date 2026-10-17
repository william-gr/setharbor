import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:setharbor/application/workout_controller.dart';
import 'package:setharbor/data/platform_gateway.dart';
import 'package:setharbor/domain/plan.dart';
import 'package:setharbor/domain/workout_state.dart';
import 'package:setharbor/domain/links.dart';
import 'package:setharbor/ui/workout_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (await PlatformGateway.channel.invokeMethod<bool>('testEnvironment') !=
        true) {
      throw StateError(
        'Integration tests require an Android E2E emulator or iOS simulator. No data was changed.',
      );
    }
    // XCTest/UiAutomation can enable accessibility during the first case,
    // introducing a platform-owned handle after flutter_test records its
    // baseline (flutter/flutter#129231). Enable it before that baseline;
    // application handle leak checks remain active and semantics stay tested.
    binding.platformDispatcher.semanticsEnabledTestValue = true;
  });
  tearDownAll(binding.platformDispatcher.clearSemanticsEnabledTestValue);
  testWidgets(
    'offline workout UI saves optional sets, advances and survives native disk reload',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(workoutProvider.future);
      final c = container.read(workoutProvider.notifier);
      await c.restore(migrateLegacy({}, c.original, c.catalog).backup());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const WorkoutApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Próximo: Treino A'), findsOneWidget);
      expect(find.text('Ver execução no Google ↗'), findsNothing);
      await tester.scrollUntilVisible(
        find.byTooltip('Mostrar detalhes · legacy-0-0'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Mostrar detalhes · legacy-0-0'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Grupo:'), findsOneWidget);
      expect(find.text('Ver execução no Google ↗'), findsOneWidget);
      await tester.tap(find.byTooltip('Ocultar detalhes · legacy-0-0'));
      await tester.pumpAndSettle();
      expect(find.text('Ver execução no Google ↗'), findsNothing);
      final check = find
          .descendant(
            of: find.byType(ExerciseCard).first,
            matching: find.byType(Checkbox),
          )
          .first;
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Concluir e salvar treino'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Concluir e salvar treino'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Concluir e salvar treino'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      final saved = container.read(workoutProvider).requireValue;
      expect(saved.next, 'day-1');
      expect(saved.history.single['sets']['0_0kg'], '');
      final disk = jsonDecode((await c.platform.readState())!) as Json;
      expect(disk['nextWorkoutId'], 'day-1');
      expect(disk['draft0'], isEmpty);
      await tester.scrollUntilVisible(
        find.text('Histórico de treinos'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Histórico de treinos')),
        alignment: .3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Histórico de treinos'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('sem carga/repetições registradas'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Catálogo de exercícios'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Catálogo de exercícios')),
        alignment: .3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catálogo de exercícios'));
      await tester.pumpAndSettle();
      expect(find.text('90 exercícios'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'supino');
      await tester.pumpAndSettle();
      expect(find.text('90 exercícios'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      container.invalidate(workoutProvider);
      final reopened = await container.read(workoutProvider.future);
      expect(reopened.next, 'day-1');
      expect(reopened.history.length, 1);
    },
  );
  testWidgets(
    'real storage preserves overrides drafts extras opaque IDs and backup v4',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(workoutProvider.future);
      final c = container.read(workoutProvider.notifier);
      final p = clone(c.original);
      p['days'][0]['id'] = 'opaque\u0000\r\n\u0001é"';
      await c.restore(
        migrateLegacy({'plan': jsonEncode(p)}, c.original, c.catalog).backup(),
      );
      await c.switchExercise(0);
      await c.edit(0, '0_0kg', '17,5');
      await c.edit(0, '0_0done', true);
      final backup = container.read(workoutProvider).requireValue.backup();
      await c.restore(backup);
      expect(
        container.read(workoutProvider).requireValue.draft['0_0kg'],
        '17,5',
      );
      await c.select(2);
      await c.edit(2, '0_0done', true);
      await c.finish();
      expect(
        container.read(workoutProvider).requireValue.next,
        workoutId(p, 0),
      );
      expect(
        container.read(workoutProvider).requireValue.history.single['extra'],
        true,
      );
      await c.finish();
      final result = container.read(workoutProvider).requireValue;
      expect(result.next, 'day-1');
      expect(
        result.history.last['plan']['days'][0]['exercises'][0]['catalogId'],
        isNot(exercisesOf(p, 0)[0]['catalogId']),
      );
      container.invalidate(workoutProvider);
      expect((await container.read(workoutProvider.future)).history.length, 2);
    },
  );
  testWidgets('offline link contract applies a plan and renders timer UI', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(workoutProvider.future);
    final c = container.read(workoutProvider.notifier);
    await c.restore(migrateLegacy({}, c.original, c.catalog).backup());
    final plan = clone(c.original)..['revision'] = 2;
    plan['title'] = 'Flutter link preview';
    // The native URL entry itself is exercised by the separate OS smoke tests.
    expect(parseWorkoutLink(encodeWorkoutLink(plan)), plan);
    await c.applyPlan(parseWorkoutLink(encodeWorkoutLink(plan)));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WorkoutApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Flutter link preview'), findsOneWidget);
    await tester.tap(find.text('90 s'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Descanso  1:'), findsOneWidget);
    await tester.tap(find.text('Parar'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
