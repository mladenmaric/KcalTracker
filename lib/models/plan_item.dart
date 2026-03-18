class PlanItem {
  final int? id;
  final int planId;
  final String mealName;     // e.g. "Breakfast"
  final int foodDefinitionId;
  final String foodName;
  final double minGrams;
  final double maxGrams;
  final double? optimalGrams; // null until solver runs
  // Denormalised nutrition (per 100g) — stored so history is stable
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  const PlanItem({
    this.id,
    required this.planId,
    required this.mealName,
    required this.foodDefinitionId,
    required this.foodName,
    required this.minGrams,
    required this.maxGrams,
    this.optimalGrams,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  // Per-gram helpers
  double get kcalPerG    => caloriesPer100g / 100;
  double get proteinPerG => proteinPer100g  / 100;
  double get carbsPerG   => carbsPer100g    / 100;
  double get fatPerG     => fatPer100g      / 100;

  // Uses optimal grams if solved, otherwise midpoint estimate
  double get _grams       => optimalGrams ?? (minGrams + maxGrams) / 2;
  double get effectiveCalories => kcalPerG    * _grams;
  double get effectiveProtein  => proteinPerG * _grams;
  double get effectiveCarbs    => carbsPerG   * _grams;
  double get effectiveFat      => fatPerG     * _grams;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'plan_id': planId,
        'meal_name': mealName,
        'food_definition_id': foodDefinitionId,
        'food_name': foodName,
        'min_grams': minGrams,
        'max_grams': maxGrams,
        'optimal_grams': optimalGrams,
        'calories_per_100g': caloriesPer100g,
        'protein_per_100g': proteinPer100g,
        'carbs_per_100g': carbsPer100g,
        'fat_per_100g': fatPer100g,
      };

  factory PlanItem.fromMap(Map<String, dynamic> map) => PlanItem(
        id: map['id'] as int?,
        planId: map['plan_id'] as int,
        mealName: map['meal_name'] as String,
        foodDefinitionId: map['food_definition_id'] as int,
        foodName: map['food_name'] as String,
        minGrams: (map['min_grams'] as num).toDouble(),
        maxGrams: (map['max_grams'] as num).toDouble(),
        optimalGrams: (map['optimal_grams'] as num?)?.toDouble(),
        caloriesPer100g: (map['calories_per_100g'] as num).toDouble(),
        proteinPer100g: (map['protein_per_100g'] as num).toDouble(),
        carbsPer100g: (map['carbs_per_100g'] as num).toDouble(),
        fatPer100g: (map['fat_per_100g'] as num).toDouble(),
      );

  PlanItem copyWith({double? optimalGrams, int? planId}) => PlanItem(
        id: id,
        planId: planId ?? this.planId,
        mealName: mealName,
        foodDefinitionId: foodDefinitionId,
        foodName: foodName,
        minGrams: minGrams,
        maxGrams: maxGrams,
        optimalGrams: optimalGrams ?? this.optimalGrams,
        caloriesPer100g: caloriesPer100g,
        proteinPer100g: proteinPer100g,
        carbsPer100g: carbsPer100g,
        fatPer100g: fatPer100g,
      );
}
