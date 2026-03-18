class TrainingEntry {
  final int? id;
  final DateTime date;
  final String type;           // e.g. "Gym", "Tennis"
  final int durationMinutes;
  final String? notes;

  const TrainingEntry({
    this.id,
    required this.date,
    required this.type,
    required this.durationMinutes,
    this.notes,
  });

  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static const List<String> presets = [
    'Gym',
    'Tennis',
    'Running',
    'Cycling',
    'Swimming',
    'Walking',
    'Yoga',
    'Other',
  ];

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date.toIso8601String(),
        'type': type,
        'duration_minutes': durationMinutes,
        'notes': notes,
      };

  factory TrainingEntry.fromMap(Map<String, dynamic> map) => TrainingEntry(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        type: map['type'] as String,
        durationMinutes: map['duration_minutes'] as int,
        notes: map['notes'] as String?,
      );
}
