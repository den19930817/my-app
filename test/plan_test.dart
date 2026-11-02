import 'package:flutter_test/flutter_test.dart';
import 'package:training_plan/plan.dart';

void main() {
  test('Copies all fields and keeps edits independent', () {
    final plan = TrainingPlan.sample();
    final original = plan.days[0].first;
    original.weight = '40 / 45 / 50';
    original.result = '12 / 10 / 8';
    original.done = true;
    expect(plan.transfer(0, 2, copy: true), isTrue);
    expect(plan.days[0].length, 3);
    expect(plan.days[2].length, 5);
    final copied = plan.days[2][2];
    expect(copied.toJson(), original.toJson());
    copied.weight = '60';
    expect(original.weight, '40 / 45 / 50');
    expect(plan.completed, 2);
  });
  test('Moves to occupied day without losing original target exercises', () {
    final plan = TrainingPlan.sample();
    final total = plan.total;
    final existing = plan.days[2].first;
    plan.days[0].first.result = '8 / 8 / 6';
    expect(plan.transfer(0, 2, copy: false), isTrue);
    expect(plan.days[0], isEmpty);
    expect(plan.days[2].first, same(existing));
    expect(plan.days[2][2].result, '8 / 8 / 6');
    expect(plan.total, total);
  });
  test('Rejects same day, empty source and invalid day', () {
    final plan = TrainingPlan.sample();
    final before = plan.encode();
    expect(plan.transfer(0, 0, copy: false), isFalse);
    expect(plan.transfer(1, 0, copy: true), isFalse);
    expect(plan.transfer(-1, 0, copy: false), isFalse);
    expect(plan.transfer(0, 7, copy: false), isFalse);
    expect(plan.encode(), before);
  });
  test('Reads previous JavaScript schema and preserves all data on roundtrip', () {
    const old =
        '[[{"name":"Тяга","sets":4,"reps":"10","done":true,"weight":"50","result":"10/10/8/8"}],[],[],[],[],[],[]]';
    final plan = TrainingPlan.decode(old);
    expect(
      TrainingPlan.decode(plan.encode()).days[0].first.toJson(),
      plan.days[0].first.toJson(),
    );
    expect(plan.days[0].first.sets, 4);
    expect(plan.days[0].first.weight, '50');
    expect(plan.days[0].first.done, isTrue);
    final minimal = TrainingPlan.decode(
      '[[{"name":"Планка","sets":3,"reps":"30 сек","done":false}],[],[],[],[],[],[]]',
    );
    expect(minimal.days[0].first.weight, '');
  });
  test('Rejects corrupt saved data', () {
    expect(() => TrainingPlan.decode('{}'), throwsFormatException);
    expect(
      () => TrainingPlan.decode('[[],[],[],[],[],[],[{}]]'),
      throwsFormatException,
    );
  });
  test('Today and yesterday wrap at Monday in local calendar', () {
    expect(dayIndex(DateTime(2026, 11, 2)), 0);
    expect((dayIndex(DateTime(2026, 11, 2)) + 6) % 7, 6);
    expect(dayIndex(DateTime(2026, 11, 8)), 6);
  });
}
