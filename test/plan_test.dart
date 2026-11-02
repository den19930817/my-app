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
  test('Migrates legacy slash-separated repetitions and weights per set', () {
    final e = Exercise.fromJson({'name':'Жим', 'sets':3, 'reps':'12', 'done':true, 'weight':'40 / 45 / 50', 'result':'12 / 10 / 8'});
    expect(e.setDetails.map((set) => set.reps), ['12', '10', '8']);
    expect(e.setDetails.map((set) => set.weight), ['40', '45', '50']);
    expect(e.result, '12 / 10 / 8');
    expect(e.done, isTrue);
  });
  test('Twenty distinct sets survive persistence and deep copy or move', () {
    final rows = List.generate(20, (i) => ExerciseSet(reps: '${i + 1}', weight: '${i + 20}.5'));
    final plan = TrainingPlan([ [Exercise(name:'Жим', sets:20, reps:'', setDetails:rows)], [], [], [], [], [], [] ]);
    final restored = TrainingPlan.decode(plan.encode());
    expect(restored.days[0].first.setDetails[19].weight, '39.5');
    expect(restored.transfer(0, 1, copy:true), isTrue);
    restored.days[1].first.setDetails[0].weight = '99';
    expect(restored.days[0].first.setDetails[0].weight, '20.5');
    expect(restored.transfer(1, 2, copy:false), isTrue);
    expect(restored.days[1], isEmpty);
    expect(restored.days[2].first.setDetails[19].reps, '20');
  });
  test('Keeps older plans with more than twenty sets and ambiguous notes', () {
    final e = Exercise(name:'Старый план', sets:25, reps:'30 секунд', weight:'свой вес', result:'');
    expect(Exercise.fromJson(e.toJson()).sets, 25);
    expect(e.setDetails.last.reps, '30 секунд');
    expect(e.setDetails.last.weight, 'свой вес');
  });
  test('Rejects malformed structured sets instead of dropping saved rows', () {
    final json = Exercise(name:'Жим', sets:3, reps:'12').toJson();
    json['setDetails'] = [{'reps':'10','weight':'30'}];
    expect(() => Exercise.fromJson(json), throwsFormatException);
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
