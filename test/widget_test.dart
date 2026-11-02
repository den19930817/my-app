import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_plan/main.dart';
import 'package:training_plan/plan.dart';

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
    expect(saved.getString('training-plan-flutter-v1'), contains('setDetails'));
    expect(saved.getString('training-plan-flutter-v1'), contains('50'));
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
