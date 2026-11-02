import 'package:shared_preferences/shared_preferences.dart';
import 'legacy_storage.dart';
import 'plan.dart';

const storageKey = 'training-plan-flutter-v1';

class LoadedPlan {
  LoadedPlan(this.plan, [this.warning = '']);
  final TrainingPlan plan;
  final String warning;
}

class PlanStorage {
  PlanStorage({String? Function()? legacyReader})
    : _legacyReader = legacyReader ?? readLegacyPlan;
  final String? Function() _legacyReader;
  Future<LoadedPlan> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getString(storageKey);
      if (current != null) return LoadedPlan(TrainingPlan.decode(current));
      final legacy = _legacyReader();
      if (legacy != null) {
        final plan = TrainingPlan.decode(legacy);
        final saved = await prefs.setString(storageKey, plan.encode());
        return LoadedPlan(
          plan,
          saved
              ? 'Ваш прежний план перенесён в Flutter.'
              : 'Прежний план открыт, но браузер не разрешил его сохранить.',
        );
      }
      return LoadedPlan(TrainingPlan.sample());
    } catch (_) {
      return LoadedPlan(
        TrainingPlan.sample(),
        'Не удалось прочитать сохранённый план. Показан пример. Исходные данные не удалены.',
      );
    }
  }

  // Queue writes so rapid edits cannot let an older save overwrite a newer one.
  Future<void> _pending = Future<void>.value();
  Future<void> save(TrainingPlan plan) {
    final value = plan.encode();
    final operation = _pending.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, value)) {
        throw StateError('Сохранение отклонено');
      }
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
