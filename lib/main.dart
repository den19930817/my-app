import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'plan.dart';
import 'storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TrainingApp());
}

const forest = Color(0xff264e3f);
const paper = Color(0xfff6f7f3);

class TrainingApp extends StatelessWidget {
  const TrainingApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Тренировочный план',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: forest,
        primary: forest,
        surface: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    ),
    home: const PlannerPage(),
  );
}

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});
  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  final _storage = PlanStorage();
  TrainingPlan? _plan;
  int _selected = dayIndex(DateTime.now());
  String _warning = '';
  int _saveVersion = 0;
  int get _today => dayIndex(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _storage.load();
    if (mounted)
      setState(() {
        _plan = loaded.plan;
        _warning = loaded.warning;
      });
  }

  Future<void> _save() async {
    final version = ++_saveVersion;
    try {
      await _storage.save(_plan!);
      if (mounted && version == _saveVersion) setState(() => _warning = '');
    } catch (_) {
      if (mounted && version == _saveVersion)
        setState(
          () => _warning =
              'Браузер не разрешил сохранение. Изменения доступны до закрытия страницы.',
        );
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _add() async {
    final day = _selected;
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (_) => const AddExerciseDialog(),
    );
    if (!mounted || exercise == null) return;
    setState(() => _plan!.days[day].add(exercise));
    await _save();
  }

  Future<void> _delete(Exercise exercise) async {
    final day = _selected;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить упражнение?'),
        content: Text(exercise.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _plan!.days[day].remove(exercise));
    await _save();
  }

  Future<void> _transfer({int? source, int? target, bool copy = false}) async {
    final from = source ?? _selected;
    if (_plan!.days[from].isEmpty) {
      _message(
        'В дне «${dayNames[from]}» пока нет упражнений для копирования.',
      );
      return;
    }
    final initialTarget = target ?? (from == _today ? (from + 1) % 7 : _today);
    final choice = await showDialog<TransferChoice>(
      context: context,
      builder: (_) => TransferDialog(
        source: from,
        target: initialTarget,
        copy: copy,
        today: _today,
      ),
    );
    if (!mounted || choice == null) return;
    final changed = _plan!.transfer(from, choice.target, copy: choice.copy);
    if (!changed) return;
    setState(() => _selected = choice.target);
    _message(
      'Тренировка ${choice.copy ? 'скопирована' : 'перенесена'}: ${dayNames[from]} → ${dayNames[choice.target]}.',
    );
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: paper,
        title: const Text(
          'Тренировочный план',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: const Icon(Icons.fitness_center, color: forest),
      ),
      body: plan == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'ТВОЙ РИТМ · ТВОЙ ПРОГРЕСС',
                        style: TextStyle(
                          color: forest,
                          letterSpacing: 2,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) => Text(
                          'Становись сильнее.\nОдну тренировку за раз.',
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 600 ? 32 : 46,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: forest,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Планируй занятия, отмечай результат и двигайся вперёд.',
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить упражнение'),
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final items = [
                            StatTile('Тренировочных дней', '${plan.sessions}'),
                            StatTile(
                              'Выполнено упражнений',
                              '${plan.completed} / ${plan.total}',
                            ),
                            StatTile('Прогресс плана', '${plan.percent}%'),
                          ];
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: items
                                .map(
                                  (item) => SizedBox(
                                    width: constraints.maxWidth < 500
                                        ? constraints.maxWidth
                                        : (constraints.maxWidth - 24) / 3,
                                    child: item,
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final workout = _workout(plan);
                          final tips = _tips(plan);
                          return constraints.maxWidth < 800
                              ? Column(
                                  children: [
                                    workout,
                                    const SizedBox(height: 20),
                                    tips,
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: workout),
                                    const SizedBox(width: 24),
                                    SizedBox(width: 280, child: tips),
                                  ],
                                );
                        },
                      ),
                      if (_warning.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _warning,
                              style: const TextStyle(color: Colors.brown),
                            ),
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'План и результаты сохраняются на этом устройстве. Демонстрационный план можно редактировать.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _workout(TrainingPlan plan) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Твоя неделя',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: List.generate(
            7,
            (i) => Semantics(
              label: dayNames[i],
              selected: i == _selected,
              child: ChoiceChip(
                label: Text(shortDayNames[i]),
                selected: i == _selected,
                onSelected: (_) => setState(() => _selected = i),
                showCheckmark: false,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '${dayNames[_selected]}${_selected == _today ? ' · сегодня' : ''}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: () => _transfer(
                source: (_today + 6) % 7,
                target: _today,
                copy: true,
              ),
              child: const Text('Скопировать со вчера'),
            ),
            OutlinedButton(
              onPressed: plan.days[_selected].isEmpty || _selected == _today
                  ? null
                  : () => _transfer(target: _today),
              child: const Text('Перенести на сегодня'),
            ),
            OutlinedButton(
              onPressed: plan.days[_selected].isEmpty
                  ? null
                  : () => _transfer(),
              child: const Text('На другой день'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (plan.days[_selected].isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('День для восстановления. Или добавь свою тренировку.'),
          ),
        ...plan.days[_selected].map(
          (exercise) => ExerciseTile(
            key: ObjectKey(exercise),
            exercise: exercise,
            onDone: (done) {
              setState(() => exercise.done = done);
              _save();
            },
            onEdit: () {
              _save();
            },
            onDelete: () => _delete(exercise),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Добавить упражнение'),
        ),
      ],
    ),
  );

  Widget _tips(TrainingPlan plan) => Column(
    children: [
      const Panel(
        color: Color(0xffe8efdb),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.spa_outlined, size: 36, color: forest),
            SizedBox(height: 20),
            Text(
              'Главное — регулярность',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Оставляй время на восстановление и выбирай комфортную нагрузку. Этот план можно менять под себя.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Шаг за шагом',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              plan.completed == 0
                  ? 'Твой следующий шаг — первая отметка в плане.'
                  : 'Выполнено ${plan.completed} из ${plan.total} упражнений. Продолжай в своём темпе.',
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: plan.total == 0 ? 0 : plan.completed / plan.total,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
      ),
    ],
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffe1e6dd)),
    ),
    child: child,
  );
}

class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            color: forest,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class ExerciseTile extends StatelessWidget {
  const ExerciseTile({
    super.key,
    required this.exercise,
    required this.onDone,
    required this.onEdit,
    required this.onDelete,
  });
  final Exercise exercise;
  final ValueChanged<bool> onDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Divider(height: 24),
      Row(
        children: [
          Checkbox(
            value: exercise.done,
            onChanged: (value) => onDone(value ?? false),
            semanticLabel: 'Выполнено: ${exercise.name}',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: exercise.done
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${exercise.sets} подх. · ${exercise.reps}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Удалить: ${exercise.name}',
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 350
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: TextFormField(
                  initialValue: exercise.weight,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Вес, кг',
                    hintText: '40 / 45 / 50',
                    counterText: '',
                  ),
                  onChanged: (value) {
                    exercise.weight = value;
                    onEdit();
                  },
                ),
              ),
              SizedBox(
                width: width,
                child: TextFormField(
                  initialValue: exercise.result,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Результат по подходам',
                    hintText: '12 / 10 / 8',
                    counterText: '',
                  ),
                  onChanged: (value) {
                    exercise.result = value;
                    onEdit();
                  },
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
    ],
  );
}

class AddExerciseDialog extends StatefulWidget {
  const AddExerciseDialog({super.key});
  @override
  State<AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<AddExerciseDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sets = TextEditingController(text: '3');
  final _reps = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _sets.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Новое упражнение'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите название'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sets,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Подходы'),
                validator: (value) {
                  final n = int.tryParse(value ?? '');
                  return n == null || n < 1 || n > 99 ? 'От 1 до 99' : null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _reps,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Повторения или время',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите повторения или время'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate())
            Navigator.pop(
              context,
              Exercise(
                name: _name.text.trim(),
                sets: int.parse(_sets.text),
                reps: _reps.text.trim(),
              ),
            );
        },
        child: const Text('Добавить'),
      ),
    ],
  );
}

class TransferChoice {
  TransferChoice(this.target, this.copy);
  final int target;
  final bool copy;
}

class TransferDialog extends StatefulWidget {
  const TransferDialog({
    super.key,
    required this.source,
    required this.target,
    required this.copy,
    required this.today,
  });
  final int source;
  final int target;
  final bool copy;
  final int today;
  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  late int _target = widget.target;
  late bool _copy = widget.copy;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Перенести или скопировать'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Из дня: ${dayNames[widget.source]}'),
            const SizedBox(height: 20),
            DropdownButtonFormField<bool>(
              initialValue: _copy,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Действие'),
              items: const [
                DropdownMenuItem(value: false, child: Text('Перенести')),
                DropdownMenuItem(value: true, child: Text('Скопировать')),
              ],
              onChanged: (value) => setState(() => _copy = value ?? false),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: _target,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'На какой день'),
              items: List.generate(7, (i) => i)
                  .where((i) => i != widget.source)
                  .map(
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${dayNames[i]}${i == widget.today ? ' (сегодня)' : ''}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _target = value ?? _target),
            ),
            const SizedBox(height: 20),
            const Text(
              'Упражнения, подходы, вес, результаты и отметки выполнения сохранятся. В выбранном дне они добавятся к существующим.',
            ),
            const SizedBox(height: 12),
            Text(
              _copy
                  ? 'Исходная тренировка останется на месте.'
                  : 'Исходный день освободится.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, TransferChoice(_target, _copy)),
        child: Text(_copy ? 'Скопировать' : 'Перенести'),
      ),
    ],
  );
}
