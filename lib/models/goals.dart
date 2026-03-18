class Goals {
  final double dailyKcal;
  final double proteinPct; // % of total calories from protein
  final double carbsPct;
  final double fatPct;

  const Goals({
    this.dailyKcal = 2000,
    this.proteinPct = 40,
    this.carbsPct = 30,
    this.fatPct = 30,
  });

  // Gram targets derived from calorie goal and macro percentages.
  // Protein & carbs = 4 kcal/g, fat = 9 kcal/g.
  double get proteinGrams => (dailyKcal * proteinPct / 100) / 4;
  double get carbsGrams   => (dailyKcal * carbsPct  / 100) / 4;
  double get fatGrams     => (dailyKcal * fatPct    / 100) / 9;

  Goals copyWith({
    double? dailyKcal,
    double? proteinPct,
    double? carbsPct,
    double? fatPct,
  }) =>
      Goals(
        dailyKcal:  dailyKcal  ?? this.dailyKcal,
        proteinPct: proteinPct ?? this.proteinPct,
        carbsPct:   carbsPct   ?? this.carbsPct,
        fatPct:     fatPct     ?? this.fatPct,
      );
}
