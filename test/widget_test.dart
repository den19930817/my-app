import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_plan/main.dart';
import 'package:training_plan/plan.dart';
import 'package:training_plan/storage.dart';

void main() {
  testWidgets('Mobile planner opens, validates input and adds an exercise', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TrainingApp());
    await tester.pumpAndSettle();
    expect(find.text('Тренировочный план'), findsOneWidget);
    await tester.tap(find.text('Добавить упражнение').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();
    expect(find.text('Введите название'), findsOneWidget);
    Finder field(String key) => find.descendant(
      of: find.byType(AddExerciseDialog),
      matching: find.byKey(ValueKey(key)),
    );
    await tester.enterText(field('exercise-name'), 'Тестовое упражнение');
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(field('set-reps-$i'));
      await tester.enterText(field('set-reps-$i'), '${12 - i}');
      await tester.enterText(field('set-weight-$i'), '${40 + i * 5}');
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();
    expect(find.text('Тестовое упражнение'), findsOneWidget);
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString(storageKey), contains('setDetails'));
    expect(saved.getString(storageKey), contains('50'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Twenty set rows, count changes preserve drafts, and each row is saved',
    (tester) async {
      Exercise? added;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  added = await showDialog<Exercise>(
                    context: context,
                    builder: (_) => const AddExerciseDialog(),
                  );
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      Future<void> selectCount(int count) async {
        final dropdown = find.byKey(const ValueKey('set-count'));
        await tester.ensureVisible(dropdown);
        final current = tester
            .widget<DropdownButtonFormField<int>>(dropdown)
            .initialValue!;
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        for (var step = 0; step < (count - current).abs(); step++) {
          await tester.sendKeyEvent(
            count < current
                ? LogicalKeyboardKey.arrowUp
                : LogicalKeyboardKey.arrowDown,
          );
          await tester.pump();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }

      await tester.enterText(
        find.byKey(const ValueKey('exercise-name')),
        'Жим',
      );
      await selectCount(20);
      expect(find.byType(SetFields), findsNWidgets(20));
      for (var i = 0; i < 20; i++) {
        final reps = find.byKey(ValueKey('set-reps-$i'));
        final weight = find.byKey(ValueKey('set-weight-$i'));
        await tester.ensureVisible(reps);
        await tester.enterText(reps, '${i + 1}');
        await tester.enterText(weight, '${i + 20},5');
      }
      await selectCount(1);
      expect(find.byType(SetFields), findsOneWidget);
      await selectCount(20);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('set-reps-19')))
            .controller!
            .text,
        '20',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
      await tester.pumpAndSettle();
      expect(added!.sets, 20);
      for (var i = 0; i < 20; i++) {
        expect(added!.setDetails[i].reps, '${i + 1}');
        expect(added!.setDetails[i].weight, '${i + 20},5');
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Existing exercise fields edit only their own set', (
    tester,
  ) async {
    final exercise = Exercise(
      name: 'Тяга',
      sets: 2,
      reps: '',
      setDetails: [
        ExerciseSet(reps: '12', weight: '40'),
        ExerciseSet(reps: '8', weight: '50'),
      ],
    );
    var edits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExerciseTile(
              exercise: exercise,
              onDone: (_) {},
              onEdit: () {
                edits++;
              },
              onDelete: () {},
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('set-reps-1')), '6');
    await tester.enterText(find.byKey(const ValueKey('set-weight-1')), '55.5');
    expect(exercise.setDetails[0].reps, '12');
    expect(exercise.setDetails[0].weight, '40');
    expect(exercise.setDetails[1].reps, '6');
    expect(exercise.setDetails[1].weight, '55.5');
    expect(edits, 2);
  });
  testWidgets('Tap exercise and set edits save and preserve other values', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final exercise = Exercise(
      name: 'Тяга',
      sets: 3,
      reps: '',
      done: true,
      setDetails: [
        ExerciseSet(reps: '12', weight: '40'),
        ExerciseSet(reps: '10', weight: '45'),
        ExerciseSet(reps: '8', weight: '50'),
      ],
    );
    final plan = TrainingPlan(List.generate(7, (_) => <Exercise>[]));
    plan.days[dayIndex(DateTime.now())].add(exercise);
    await prefs.setString(storageKey, plan.encode());
    await tester.pumpWidget(const TrainingApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Тяга'));
    await tester.tap(find.text('Тяга'));
    await tester.pumpAndSettle();
    expect(find.text('Изменить упражнение'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('exercise-name')),
      'Тяга блока',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Тяга блока'), findsOneWidget);
    final setButton = find.widgetWithText(TextButton, 'Подход 2');
    await tester.ensureVisible(setButton);
    await tester.tap(setButton);
    await tester.pumpAndSettle();
    final dialog = find.byType(AddExerciseDialog);
    expect(
      find.descendant(of: dialog, matching: find.byType(SetFields)),
      findsOneWidget,
    );
    final reps = find.descendant(
      of: dialog,
      matching: find.byKey(const ValueKey('set-reps-1')),
    );
    final weight = find.descendant(
      of: dialog,
      matching: find.byKey(const ValueKey('set-weight-1')),
    );
    await tester.enterText(reps, '6');
    await tester.enterText(weight, '55.5');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    final saved = TrainingPlan.decode(
      prefs.getString(storageKey)!,
    ).days[dayIndex(DateTime.now())].first;
    expect(saved.name, 'Тяга блока');
    expect(saved.done, isTrue);
    expect(saved.setDetails.map((set) => set.reps), ['12', '6', '8']);
    expect(saved.setDetails.map((set) => set.weight), ['40', '55.5', '50']);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Exercise editor changes set count while cancellation discards draft',
    (tester) async {
      final original = Exercise(
        name: 'Жим',
        sets: 3,
        reps: '12',
        done: true,
        weight: '40',
        result: '12 / 10 / 8',
      );
      Exercise? edited;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  edited = await showDialog<Exercise>(
                    context: context,
                    builder: (_) => AddExerciseDialog(exercise: original),
                  );
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('exercise-name')),
        'Черновик',
      );
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(edited, isNull);
      expect(original.name, 'Жим');
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('set-count')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(SetFields), findsNWidgets(2));
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(edited!.sets, 2);
      expect(edited!.setDetails.map((set) => set.reps), ['12', '10']);
      expect(edited!.done, isTrue);
      expect(edited!.weight, '40');
      expect(original.sets, 3);
    },
  );
  testWidgets('Transfer dialog supports copy mode and cancellation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<TransferChoice>(
                context: context,
                builder: (_) => const TransferDialog(
                  source: 0,
                  target: 1,
                  copy: true,
                  today: 1,
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(
      find.text('Исходная тренировка останется на месте.'),
      findsOneWidget,
    );
    expect(find.text('Вторник (сегодня)'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.byType(TransferDialog), findsNothing);
  });
}
