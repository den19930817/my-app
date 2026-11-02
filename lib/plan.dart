import 'dart:convert';

const dayNames = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
const shortDayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
int dayIndex(DateTime date) => date.weekday - 1;

class Exercise {
  Exercise({required this.name, required this.sets, required this.reps, this.done = false, this.weight = '', this.result = ''});
  final String name;
  final int sets;
  final String reps;
  bool done;
  String weight;
  String result;
  factory Exercise.fromJson(Map<String, dynamic> json) {
    if (json['name'] is! String || json['sets'] is! int || (json['sets'] as int) < 1 || (json['sets'] as int) > 99 || json['reps'] is! String || json['done'] is! bool || (json['weight'] != null && json['weight'] is! String) || (json['result'] != null && json['result'] is! String)) {
      throw const FormatException('Некорректное упражнение');
    }
    return Exercise(name: json['name'] as String, sets: json['sets'] as int, reps: json['reps'] as String, done: json['done'] as bool, weight: json['weight'] as String? ?? '', result: json['result'] as String? ?? '');
  }
  Map<String, dynamic> toJson() => {'name': name, 'sets': sets, 'reps': reps, 'done': done, 'weight': weight, 'result': result};
  Exercise copy() => Exercise.fromJson(toJson());
}

class TrainingPlan {
  TrainingPlan(this.days) {
    if (days.length != 7) throw const FormatException('В плане должно быть семь дней');
  }
  final List<List<Exercise>> days;
  factory TrainingPlan.decode(String value) {
    final json = jsonDecode(value);
    if (json is! List || json.length != 7) throw const FormatException('Некорректный план');
    return TrainingPlan(json.map((day) {
      if (day is! List) throw const FormatException('Некорректный день');
      return day.map((e) {
        if (e is! Map<String, dynamic>) throw const FormatException('Некорректное упражнение');
        return Exercise.fromJson(e);
      }).toList();
    }).toList());
  }
  factory TrainingPlan.sample() => TrainingPlan([
    [Exercise(name: 'Приседания', sets: 3, reps: '12 повторений'), Exercise(name: 'Отжимания', sets: 3, reps: '10 повторений'), Exercise(name: 'Планка', sets: 3, reps: '30 секунд')],
    [], [Exercise(name: 'Выпады', sets: 3, reps: '10 на каждую ногу'), Exercise(name: 'Ягодичный мост', sets: 3, reps: '15 повторений')], [],
    [Exercise(name: 'Приседания', sets: 3, reps: '12 повторений'), Exercise(name: 'Планка', sets: 3, reps: '30 секунд')], [], []
  ]);
  int get total => days.fold(0, (sum, day) => sum + day.length);
  int get completed => days.expand((day) => day).where((e) => e.done).length;
  int get sessions => days.where((day) => day.isNotEmpty).length;
  int get percent => total == 0 ? 0 : (completed / total * 100).round();
  String encode() => jsonEncode(days.map((day) => day.map((e) => e.toJson()).toList()).toList());
  bool transfer(int source, int target, {required bool copy}) {
    if (source < 0 || source > 6 || target < 0 || target > 6 || source == target || days[source].isEmpty) return false;
    days[target].addAll(days[source].map((e) => e.copy()));
    if (!copy) days[source].clear();
    return true;
  }
}
