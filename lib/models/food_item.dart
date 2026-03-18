// A logged food entry inside a meal.
// Calories and macros are stored as calculated values (grams × per-100g values)
// so the history is never affected if you later edit the food definition.
class FoodItem {
  final int? id;
  final int mealId;
  final int foodDefinitionId; // reference to the food database entry
  final String name; // denormalised — shown even if definition is later deleted
  final double grams; // how much the user actually ate
  final double calories; // calculated: caloriesPer100g × grams / 100
  final double protein;
  final double carbs;
  final double fat;

  const FoodItem({
    this.id,
    required this.mealId,
    required this.foodDefinitionId,
    required this.name,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'meal_id': mealId,
        'food_definition_id': foodDefinitionId,
        'name': name,
        'grams': grams,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory FoodItem.fromMap(Map<String, dynamic> map) => FoodItem(
        id: map['id'] as int?,
        mealId: map['meal_id'] as int,
        foodDefinitionId: map['food_definition_id'] as int,
        name: map['name'] as String,
        grams: (map['grams'] as num).toDouble(),
        calories: (map['calories'] as num).toDouble(),
        protein: (map['protein'] as num).toDouble(),
        carbs: (map['carbs'] as num).toDouble(),
        fat: (map['fat'] as num).toDouble(),
      );
}
