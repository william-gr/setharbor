import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/workout_controller.dart';
import '../data/platform_gateway.dart';
import '../domain/catalog.dart';
import '../domain/links.dart';
import '../domain/plan.dart';
import '../domain/workout_state.dart';

class WorkoutApp extends StatelessWidget {
  const WorkoutApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SetHarbor',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff71e5ac),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff101820),
      useMaterial3: true,
    ),
    home: const WorkoutHome(),
  );
}

class WorkoutHome extends ConsumerStatefulWidget {
  const WorkoutHome({super.key});
  @override
  ConsumerState<WorkoutHome> createState() => _WorkoutHomeState();
}

class _WorkoutHomeState extends ConsumerState<WorkoutHome> {
  late final PlatformGateway gateway;
  final _scroll = ScrollController();
  int _formVersion = 0;
  bool _busy = false;
  Future<void> _links = Future.value();
  WorkoutController get controller => ref.read(workoutProvider.notifier);
  WorkoutState get current => ref.read(workoutProvider).requireValue;
  @override
  void initState() {
    super.initState();
    gateway = ref.read(platformProvider);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      await ref.read(workoutProvider.future);
      if (!mounted) return;
      controller.platform.listenLinks(_receiveLink);
      final link = await controller.platform.initialLink();
      if (!mounted) return;
      if (link != null) {
        _receiveLink(link);
      } else {
        unawaited(_sync(false));
      }
    } catch (_) {
      /* Async provider displays startup/storage failure without resetting data. */
    }
  }

  @override
  void dispose() {
    gateway.stopListening();
    _scroll.dispose();
    super.dispose();
  }

  void refreshForm() {
    if (!mounted) return;
    setState(() => _formVersion++);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void message(String text) {
    if (!mounted || text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String errorText(Object error) => error is FormatException
      ? error.message
      : error is PlatformException
      ? error.message ?? 'Não foi possível concluir.'
      : 'Não foi possível concluir. Seus registros foram mantidos.';
  Future<void> guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      message(errorText(error));
    }
  }

  Future<bool> confirm(String title, Widget content, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _exclusive(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await guard(action);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finish() => _exclusive(() async {
    FocusScope.of(context).unfocus();
    await controller.flush();
    final count = current.completedCount();
    final next = current.selected == current.nextIndex
        ? workoutLabel((current.selected + 1) % daysOf(current.plan).length)
        : workoutLabel(current.nextIndex);
    if (!mounted ||
        !await confirm(
          'Salvar treino?',
          Text(
            '$count séries concluídas. As séries não marcadas ficam fora do histórico.\n${current.selected == current.nextIndex ? 'Próximo: $next' : 'Sessão extra. Próximo continua: $next'}',
          ),
          'Salvar',
        )) {
      return;
    }
    await controller.finish();
    refreshForm();
    message('Treino salvo!');
  });
  void _receiveLink(String address) {
    controller.linkPending = true;
    _links = _links.then((_) async {
      if (!mounted) return;
      try {
        final plan = parseWorkoutLink(address);
        if (await confirm(
          'Aplicar treino do link?',
          PlanPreview(plan: plan),
          'Aplicar treino',
        )) {
          final reset = await controller.applyPlan(plan);
          refreshForm();
          message(
            'Ficha atualizada. ${reset ? 'Sequência reiniciada no treino A. ' : ''}Histórico preservado.',
          );
        }
      } catch (error) {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Link de treino inválido'),
              content: Text('A ficha não foi alterada. ${errorText(error)}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    });
    final pending = _links;
    unawaited(
      pending.whenComplete(() {
        if (identical(pending, _links) && mounted) {
          controller.linkPending = false;
        }
      }),
    );
  }

  Future<void> _importPlan() => _exclusive(() async {
    final text = await controller.platform.pickDocument(1024 * 1024);
    if (text == null || !mounted) return;
    final plan = jsonDecode(text) as Json;
    validatePlan(plan);
    if (await confirm('Importar ficha?', PlanPreview(plan: plan), 'Importar')) {
      final reset = await controller.applyPlan(plan);
      refreshForm();
      message(
        'Ficha atualizada. ${reset ? 'Sequência reiniciada no treino A. ' : ''}Histórico preservado.',
      );
    }
  });
  Future<void> _restore() => _exclusive(() async {
    final text = await controller.platform.pickDocument(10 * 1024 * 1024);
    if (text == null || !mounted) return;
    final backup = jsonDecode(text) as Json;
    restoreBackup(backup, controller.original, controller.catalog);
    if (await confirm(
      'Restaurar backup?',
      const Text(
        'Isso substituirá o histórico e as séries em andamento por este backup.',
      ),
      'Restaurar',
    )) {
      await controller.restore(backup);
      refreshForm();
      message('Backup restaurado.');
    }
  });
  Future<void> _export() => _exclusive(() async {
    await controller.flush();
    if (await controller.platform.exportDocument(
      const JsonEncoder.withIndent('  ').convert(current.backup()),
    )) {
      message('Backup exportado.');
    }
  });
  Future<void> _sync(bool feedback) async {
    try {
      final result = await controller.sync();
      if (feedback) message(result);
    } catch (error) {
      if (feedback) message(errorText(error));
    }
  }

  Future<void> _configureSync() async {
    var address = current.planUrl;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atualização automática ao abrir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'URL HTTPS da ficha JSON. Sem URL, o app continua offline. Só revisões novas são aplicadas, sem treinos em andamento.',
            ),
            TextFormField(
              initialValue: address,
              onChanged: (value) => address = value,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://…/treino.json',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Desativar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, address.trim()),
            child: const Text('Salvar e verificar'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await guard(() async {
      await controller.configureUrl(result);
      if (result.isNotEmpty) await _sync(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workoutProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('SetHarbor')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Não foi possível carregar seus dados. Os arquivos existentes foram preservados.',
                ),
                TextButton(
                  onPressed: () {
                    ref.invalidate(workoutProvider);
                    unawaited(_boot());
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
        data: (s) {
          final catalog = controller.catalog;
          return AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  s.plan['title'],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey('day-${s.selected}'),
                  initialValue: s.selected,
                  decoration: const InputDecoration(
                    labelText: 'Treino da sequência',
                  ),
                  items: [
                    for (var d = 0; d < daysOf(s.plan).length; d++)
                      DropdownMenuItem(value: d, child: Text(workoutLabel(d))),
                  ],
                  onChanged: (d) {
                    if (d != null) unawaited(guard(() => controller.select(d)));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Próximo: ${workoutLabel(s.nextIndex)}',
                    style: const TextStyle(color: Color(0xff71e5ac)),
                  ),
                ),
                if (s.selected != s.nextIndex)
                  TextButton(
                    onPressed: () => guard(() => controller.defineNext()),
                    child: const Text('Definir como próximo'),
                  ),
                Text(
                  daysOf(s.plan)[s.selected]['focus'] ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey('phase-${s.phase}'),
                  initialValue: s.phase,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Modo do treino',
                  ),
                  items: [
                    for (final (index, label) in [
                      'Semana 1 · 2 séries · RIR 3–4',
                      'Semana 2 · volume completo · RIR 2',
                      'Normal · volume completo · RIR 1–2',
                    ].indexed)
                      DropdownMenuItem(
                        value: index,
                        child: Text(label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (phase) {
                    if (phase != null) {
                      unawaited(guard(() => controller.setPhase(phase)));
                    }
                  },
                ),
                const RestTimer(key: ValueKey('rest-timer')),
                for (var e = 0; e < exercisesOf(s.plan, s.selected).length; e++)
                  ExerciseCard(
                    key: ValueKey(
                      '$_formVersion-${s.selected}-${exercisesOf(s.plan, s.selected)[e]['id']}-${catalog.effective(exercisesOf(s.plan, s.selected)[e], s.draft)['catalogId']}',
                    ),
                    state: s,
                    catalog: catalog,
                    index: e,
                    onEdit: (key, value) =>
                        guard(() => controller.edit(s.selected, key, value)),
                    onSwap: () => guard(() => controller.switchExercise(e)),
                    onSearch: (name) => guard(
                      () => controller.platform.openUrl(
                        executionUrl(name).toString(),
                      ),
                    ),
                  ),
                const Text(
                  'Peso e repetições são opcionais: basta marcar as séries feitas para salvar. Confira a unidade de carga nos detalhes. Aquecimentos não entram nas séries.',
                ),
                FilledButton(
                  onPressed: _finish,
                  child: const Text('Concluir e salvar treino'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => HistoryScreen(state: s),
                    ),
                  ),
                  child: const Text('Histórico de treinos'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CatalogScreen(
                        catalog: catalog,
                        onSearch: (name) => guard(
                          () => controller.platform.openUrl(
                            executionUrl(name).toString(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Catálogo de exercícios'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Planejamento: pedido curto com link para instruções e catálogo. Revisar inclui a ficha atual, sem histórico ou cargas.',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => guard(
                    () => controller.platform.share(chatPrompt(s.plan, false)),
                  ),
                  child: const Text('Planejar com ChatGPT'),
                ),
                OutlinedButton(
                  onPressed: () => guard(
                    () => controller.platform.share(chatPrompt(s.plan, true)),
                  ),
                  child: const Text('Revisar ficha com ChatGPT'),
                ),
                if (Platform.isAndroid)
                  TextButton(
                    onPressed: () =>
                        guard(() => controller.platform.linkSettings()),
                    child: const Text('Abrir links do ChatGPT diretamente'),
                  ),
                OutlinedButton(
                  onPressed: _importPlan,
                  child: const Text('Importar ficha de treino'),
                ),
                OutlinedButton(
                  onPressed: _configureSync,
                  child: const Text('Atualização online'),
                ),
                OutlinedButton(
                  onPressed: _export,
                  child: const Text('Exportar backup'),
                ),
                OutlinedButton(
                  onPressed: _restore,
                  child: const Text('Restaurar backup'),
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Gratuito · Open source · MIT',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PlanPreview extends StatelessWidget {
  final Json plan;
  const PlanPreview({super.key, required this.plan});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${plan['title']} · revisão ${plan['revision']}'),
      const Text('Histórico preservado. Fichas novas começam no treino A.'),
      for (final (index, day) in daysOf(plan).indexed) ...[
        const SizedBox(height: 16),
        Text('${workoutLabel(index)} · ${day['name']} · ${day['focus'] ?? ''}'),
        for (final item in day['exercises'])
          Text('${item['name']} — ${item['sets']} × ${item['reps']}'),
      ],
    ],
  );
}

class ExerciseCard extends StatefulWidget {
  final WorkoutState state;
  final Catalog catalog;
  final int index;
  final Future<void> Function(String, Object) onEdit;
  final Future<void> Function() onSwap;
  final Future<void> Function(String) onSearch;
  const ExerciseCard({
    super.key,
    required this.state,
    required this.catalog,
    required this.index,
    required this.onEdit,
    required this.onSwap,
    required this.onSearch,
  });
  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool details = false, showDone = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.state, catalog = widget.catalog, e = widget.index;
    final planned = exercisesOf(s.plan, s.selected)[e],
        item = catalog.effective(planned, s.draft),
        known = catalog.resolve(item);
    final name = item['name'] as String,
        slot = planned['id'] as String,
        count = s.setCount(planned);
    final completed = List.generate(
      count,
      (i) => s.draft['${e}_${i}done'] == true,
    ).where((v) => v).length;
    final last = s.lastPerformance(item, catalog);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (known != null) ...[
                  IconButton(
                    tooltip:
                        '${details ? 'Ocultar' : 'Mostrar'} detalhes · $slot',
                    onPressed: () => setState(() => details = !details),
                    icon: const Icon(Icons.info_outline),
                  ),
                  IconButton(
                    tooltip: 'Trocar por similar · $slot',
                    onPressed: widget.onSwap,
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ],
              ],
            ),
            if (details && known != null)
              ExerciseDetails(catalog: catalog, item: known),
            if ((s.draft['exerciseOverrides'] as Json?)?.containsKey(slot) ??
                false)
              Text(
                'Só neste treino${details ? ' · Planejado: ${planned['name']}' : ''}',
              ),
            TextButton(
              onPressed: () => widget.onSearch(name),
              child: const Text('Ver execução no Google ↗'),
            ),
            Text('$count séries × ${planned['reps']} reps'),
            if (last.isNotEmpty) Text('Último: $last'),
            for (var i = 0; i < count; i++)
              if (showDone || s.draft['${e}_${i}done'] != true)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 24, child: Text('${i + 1}')),
                      for (final (suffix, label, decimal) in [
                        ('kg', 'Carga', true),
                        ('reps', 'Repetições', false),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Semantics(
                              label: '$label · $slot · ${i + 1}',
                              child: TextFormField(
                                key: ValueKey('${e}_$i$suffix'),
                                initialValue: s.draft['${e}_$i$suffix'] ?? '',
                                decoration: InputDecoration(
                                  labelText: '$label · ${i + 1}',
                                  hintText: decimal ? 'kg' : 'reps',
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: decimal,
                                ),
                                onChanged: (value) => unawaited(
                                  widget.onEdit('${e}_$i$suffix', value),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Semantics(
                        label: 'Série ${i + 1} concluída em $name',
                        child: Checkbox(
                          value: s.draft['${e}_${i}done'] == true,
                          onChanged: (done) {
                            FocusScope.of(context).unfocus();
                            unawaited(
                              widget.onEdit('${e}_${i}done', done ?? false),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            if (completed > 0) ...[
              Text('$completed de $count séries concluídas'),
              TextButton(
                onPressed: () => setState(() => showDone = !showDone),
                child: Text(
                  showDone
                      ? 'Ocultar séries concluídas'
                      : 'Mostrar séries concluídas',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ExerciseDetails extends StatelessWidget {
  final Catalog catalog;
  final Json item;
  const ExerciseDetails({super.key, required this.catalog, required this.item});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Grupo: ${catalog.label('groups', item['group'])}'),
      for (final (field, label) in [
        ('primaryMuscles', 'Principais'),
        ('secondaryMuscles', 'Secundários'),
        ('stabilizerMuscles', 'Estabilizadores'),
      ])
        if ((item[field] as List).isNotEmpty)
          Text('$label: ${catalog.labels('muscles', item[field])}'),
      Text(
        'Equipamento: ${catalog.labels('equipment', item['equipment'])} · ${catalog.loadHint(item)}',
      ),
      Text(item['notes'] ?? ''),
    ],
  );
}

class RestTimer extends StatefulWidget {
  const RestTimer({super.key});
  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer>
    with AutomaticKeepAliveClientMixin<RestTimer> {
  @override
  bool get wantKeepAlive => true;
  final watch = Stopwatch();
  Timer? timer;
  int duration = 0, remaining = 0;
  void start(int seconds) {
    timer?.cancel();
    watch.reset();
    watch.start();
    setState(() {
      duration = seconds;
      remaining = seconds;
    });
    timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final next = (duration - watch.elapsed.inSeconds).clamp(0, duration);
      if (next != remaining && mounted) setState(() => remaining = next);
      if (next == 0) {
        timer?.cancel();
        watch.stop();
        unawaited(SystemSound.play(SystemSoundType.alert));
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    watch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              duration == 0
                  ? 'Descanso'
                  : remaining == 0
                  ? 'Descanso concluído'
                  : 'Descanso  ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
            ),
            Row(
              children: [
                for (final sec in [60, 90, 120])
                  Expanded(
                    child: TextButton(
                      onPressed: () => start(sec),
                      child: Text('$sec s'),
                    ),
                  ),
              ],
            ),
            TextButton(
              onPressed: () {
                timer?.cancel();
                watch.stop();
                setState(() {
                  duration = 0;
                  remaining = 0;
                });
              },
              child: const Text('Parar'),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final WorkoutState state;
  const HistoryScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Histórico')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.history.isEmpty) const Text('Nenhum treino concluído ainda.'),
        for (final rec in state.history.reversed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rec['workoutLabel'] ?? daysOf(rec['plan'])[rec['day']]['name']}${rec['extra'] == true ? ' · Extra' : ''} · ${rec['date']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final (e, item) in exercisesOf(
                    rec['plan'],
                    rec['day'],
                  ).indexed)
                    if (List.generate(
                      item['sets'],
                      (i) => rec['sets']['${e}_${i}done'] == true,
                    ).any((v) => v))
                      Text(
                        '${item['name']}\n${[for (var i = 0; i < item['sets']; i++)
                          if (rec['sets']['${e}_${i}done'] == true) setSummary(rec['sets']['${e}_${i}kg'] ?? '', rec['sets']['${e}_${i}reps'] ?? '')].join(' / ')}',
                      ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class CatalogScreen extends StatefulWidget {
  final Catalog catalog;
  final Future<void> Function(String) onSearch;
  const CatalogScreen({
    super.key,
    required this.catalog,
    required this.onSearch,
  });
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final catalog = widget.catalog;
    final items = catalog.exercises.values
        .where(
          (item) => Catalog.normalize(
            '${catalog.name(item)} ${catalog.label('groups', item['group'])} ${catalog.labels('muscles', item['primaryMuscles'])} ${item['aliases']}',
          ).contains(Catalog.normalize(query)),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de exercícios')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar exercício ou músculo',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Text('${items.length} exercícios'),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ExpansionTile(
                  title: Text(catalog.name(item)),
                  subtitle: Text(catalog.label('groups', item['group'])),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ExerciseDetails(catalog: catalog, item: item),
                    ),
                    TextButton(
                      onPressed: () => widget.onSearch(catalog.name(item)),
                      child: const Text('Ver execução no Google ↗'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
