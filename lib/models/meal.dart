import 'food_item.dart';

// A Meal groups food items together (e.g. "Breakfast", "Lunch").
class Meal {
  final int? id;
  final String name; // e.g. "Breakfast"
  final DateTime date; // stored as ISO-8601 string in SQLite
  final List<FoodItem> foodItems; // loaded separately, not a DB column

  const Meal({
    this.id,
    required this.name,
    required this.date,
    this.foodItems = const [],
  });

  // Total calories across all food items in this meal.
  double get totalCalories =>
      foodItems.fold(0, (sum, item) => sum + item.calories);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'date': date.toIso8601String(),
      };

  factory Meal.fromMap(Map<String, dynamic> map) => Meal(
        id: map['id'] as int?,
        name: map['name'] as String,
        date: DateTime.parse(map['date'] as String),
      );

  Meal copyWith({
    int? id,
    String? name,
    DateTime? date,
    List<FoodItem>? foodItems,
  }) =>
      Meal(
        id: id ?? this.id,
        name: name ?? this.name,
        date: date ?? this.date,
        foodItems: foodItems ?? this.foodItems,
      );
}
