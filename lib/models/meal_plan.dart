import 'plan_item.dart';

class MealPlan {
  final int? id;
  final DateTime date;
  final String name;
  final double goalKcal;
  final double proteinGoalG;
  final double carbsGoalG;
  final double fatGoalG;
  final bool isSolved;
  final List<PlanItem> items; // loaded separately

  const MealPlan({
    this.id,
    required this.date,
    required this.name,
    required this.goalKcal,
    required this.proteinGoalG,
    required this.carbsGoalG,
    required this.fatGoalG,
    this.isSolved = false,
    this.items = const [],
  });

  // Totals using optimal grams (if solved), otherwise midpoint estimate.
  double get totalKcal    => items.fold(0, (s, i) => s + i.effectiveCalories);
  double get totalProtein => items.fold(0, (s, i) => s + i.effectiveProtein);
  double get totalCarbs   => items.fold(0, (s, i) => s + i.effectiveCarbs);
  double get totalFat     => items.fold(0, (s, i) => s + i.effectiveFat);

  /// Groups items by meal name in insertion order.
  Map<String, List<PlanItem>> get byMeal {
    final map = <String, List<PlanItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.mealName, () => []).add(item);
    }
    return map;
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date.toIso8601String(),
        'name': name,
        'goal_kcal': goalKcal,
        'protein_goal_g': proteinGoalG,
        'carbs_goal_g': carbsGoalG,
        'fat_goal_g': fatGoalG,
        'is_solved': isSolved ? 1 : 0,
      };

  factory MealPlan.fromMap(Map<String, dynamic> map) => MealPlan(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        name: map['name'] as String,
        goalKcal: (map['goal_kcal'] as num).toDouble(),
        proteinGoalG: (map['protein_goal_g'] as num).toDouble(),
        carbsGoalG: (map['carbs_goal_g'] as num).toDouble(),
        fatGoalG: (map['fat_goal_g'] as num).toDouble(),
        isSolved: (map['is_solved'] as int) == 1,
      );

  MealPlan copyWith({
    int? id,
    List<PlanItem>? items,
    bool? isSolved,
  }) =>
      MealPlan(
        id: id ?? this.id,
        date: date,
        name: name,
        goalKcal: goalKcal,
        proteinGoalG: proteinGoalG,
        carbsGoalG: carbsGoalG,
        fatGoalG: fatGoalG,
        isSolved: isSolved ?? this.isSolved,
        items: items ?? this.items,
      );
}
