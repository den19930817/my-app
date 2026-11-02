import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_plan/main.dart';

void main() {
  testWidgets('Mobile planner opens, validates input and adds an exercise', (tester) async {
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
    final fields = find.descendant(of: find.byType(AddExerciseDialog), matching: find.byType(TextFormField));
    await tester.enterText(fields.at(0), 'Тестовое упражнение');
    await tester.enterText(fields.at(2), '12 повторений');
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();
    expect(find.text('Тестовое упражнение'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Transfer dialog supports copy mode and cancellation', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => showDialog<TransferChoice>(context: context, builder: (_) => const TransferDialog(source: 0, target: 1, copy: true, today: 1)), child: const Text('Открыть'),
    )))));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('Исходная тренировка останется на месте.'), findsOneWidget);
    expect(find.text('Вторник (сегодня)'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.byType(TransferDialog), findsNothing);
  });
}
