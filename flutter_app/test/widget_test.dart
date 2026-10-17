import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:io';

import 'package:setharbor/domain/catalog.dart';
import 'package:setharbor/domain/plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setharbor/application/workout_controller.dart';
import 'package:setharbor/ui/workout_app.dart';

import 'controller_test.dart' show MemoryPlatform;

void main() {
  testWidgets(
    'real app loads Riverpod state, details, optional sets and cyclic save',
    (tester) async {
      final platform = MemoryPlatform();
      final original = jsonDecode(
        File('assets/default-plan.json').readAsStringSync(),
      ) as Json;
      final catalog = Catalog(
        jsonDecode(File('assets/exercise-catalog.json').readAsStringSync())
            as Json,
        original,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            platformProvider.overrideWithValue(platform),
            assetsProvider.overrideWith(
              (ref) async => (original: original, catalog: catalog),
            ),
          ],
          child: const WorkoutApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SetHarbor'), findsOneWidget);
      expect(find.text('Próximo: Treino A'), findsOneWidget);
      expect(find.textContaining('Grupo:'), findsNothing);
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
      final card = find.byType(ExerciseCard).first;
      final check = find
          .descendant(of: card, matching: find.byType(Checkbox))
          .first;
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(find.text('1 de 2 séries concluídas'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Concluir e salvar treino'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Concluir e salvar treino'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Concluir e salvar treino'));
      await tester.pumpAndSettle();
      expect(find.text('Salvar treino?'), findsOneWidget);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 10000));
      await tester.pumpAndSettle();
      expect(find.text('Próximo: Treino B'), findsOneWidget);
      expect(platform.disk, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('timer uses elapsed time and stops', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RestTimer())),
    );
    await tester.tap(find.text('60 s'));
    await tester.pump();
    expect(find.text('Descanso  1:00'), findsOneWidget);
    await tester.tap(find.text('Parar'));
    await tester.pump();
    expect(find.text('Descanso'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'rest timer survives scrolling offscreen and keyed list reordering',
    (tester) async {
      var insert = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return ListView(
                  children: [
                    if (insert) const Text('Definir como próximo'),
                    const RestTimer(key: ValueKey('rest-timer')),
                    for (var i = 0; i < 30; i++)
                      SizedBox(height: 150, child: Text('Exercise $i')),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('90 s'));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -1800));
      await tester.pumpAndSettle();
      update(() => insert = true);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 5000));
      await tester.pumpAndSettle();
      expect(find.textContaining('Descanso  '), findsOneWidget);
      expect(find.text('Descanso'), findsNothing);
      await tester.tap(find.text('Parar'));
      await tester.pump();
      expect(find.text('Descanso'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
