// A food definition is an entry in your personal food database.
// It stores nutritional values per 100g so the app can calculate
// actual intake when the user enters how many grams they ate.
class FoodDefinition {
  final int? id;
  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  const FoodDefinition({
    this.id,
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  // Calculate calories for a given number of grams.
  double caloriesForGrams(double grams) => caloriesPer100g * grams / 100;
  double proteinForGrams(double grams) => proteinPer100g * grams / 100;
  double carbsForGrams(double grams) => carbsPer100g * grams / 100;
  double fatForGrams(double grams) => fatPer100g * grams / 100;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'calories_per_100g': caloriesPer100g,
        'protein_per_100g': proteinPer100g,
        'carbs_per_100g': carbsPer100g,
        'fat_per_100g': fatPer100g,
      };

  factory FoodDefinition.fromMap(Map<String, dynamic> map) => FoodDefinition(
        id: map['id'] as int?,
        name: map['name'] as String,
        caloriesPer100g: (map['calories_per_100g'] as num).toDouble(),
        proteinPer100g: (map['protein_per_100g'] as num).toDouble(),
        carbsPer100g: (map['carbs_per_100g'] as num).toDouble(),
        fatPer100g: (map['fat_per_100g'] as num).toDouble(),
      );

  FoodDefinition copyWith({
    int? id,
    String? name,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
  }) =>
      FoodDefinition(
        id: id ?? this.id,
        name: name ?? this.name,
        caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
        proteinPer100g: proteinPer100g ?? this.proteinPer100g,
        carbsPer100g: carbsPer100g ?? this.carbsPer100g,
        fatPer100g: fatPer100g ?? this.fatPer100g,
      );
}
