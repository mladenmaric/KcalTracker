class WeightEntry {
  final int? id;
  final DateTime date;
  final double weightKg;

  const WeightEntry({
    this.id,
    required this.date,
    required this.weightKg,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date.toIso8601String(),
        'weight_kg': weightKg,
      };

  factory WeightEntry.fromMap(Map<String, dynamic> map) => WeightEntry(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        weightKg: (map['weight_kg'] as num).toDouble(),
      );
}
