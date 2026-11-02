import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_plan/plan.dart';
import 'package:training_plan/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Imports legacy plan once, then prefers the Flutter version', () async {
    final legacy = TrainingPlan.sample();
    legacy.days[0].first.weight = '80';
    final storage = PlanStorage(legacyReader: () => legacy.encode());
    final loaded = await storage.load();
    expect(loaded.plan.days[0].first.weight, '80');
    loaded.plan.days[0].first.weight = '85';
    await storage.save(loaded.plan);
    final reopened = await storage.load();
    expect(reopened.plan.days[0].first.weight, '85');
  });
  test('Migrates the latest Flutter plan before old JavaScript data and keeps original', () async {
    final prefs = await SharedPreferences.getInstance();
    final original = TrainingPlan.sample();
    original.days[0].first.setDetails[0].weight = '75';
    await prefs.setString(previousStorageKey, original.encode());
    final storage = PlanStorage(legacyReader: () => throw StateError('Stale JavaScript data must not be read'));
    final loaded = await storage.load();
    expect(loaded.plan.days[0].first.setDetails[0].weight, '75');
    loaded.plan.days[0].first.setDetails[0].weight = '80';
    await storage.save(loaded.plan);
    expect(TrainingPlan.decode(prefs.getString(previousStorageKey)!).days[0].first.setDetails[0].weight, '75');
    expect((await storage.load()).plan.days[0].first.setDetails[0].weight, '80');
  });
  test('Queued saves persist the latest edit', () async {
    final storage = PlanStorage(legacyReader: () => null);
    final plan = TrainingPlan.sample();
    final first = storage.save(plan);
    plan.days[0].first.result = '12 / 11 / 9';
    final second = storage.save(plan);
    await Future.wait([first, second]);
    expect((await storage.load()).plan.days[0].first.result, '12 / 11 / 9');
  });
  test('Corrupt legacy data is not imported or overwritten', () async {
    final storage = PlanStorage(legacyReader: () => '{bad json');
    final loaded = await storage.load();
    expect(loaded.warning, isNotEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(storageKey), isNull);
  });
}
