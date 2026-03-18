class SleepEntry {
  final int? id;
  final DateTime date; // the day this entry belongs to
  final String? sleepTime; // "HH:mm" — when they went to bed
  final String? wakeTime;  // "HH:mm" — when they woke up

  const SleepEntry({
    this.id,
    required this.date,
    this.sleepTime,
    this.wakeTime,
  });

  // Duration in minutes, accounting for sleeping past midnight.
  int? get durationMinutes {
    final s = _parseTime(sleepTime);
    final w = _parseTime(wakeTime);
    if (s == null || w == null) return null;
    final diff = w - s;
    return diff >= 0 ? diff : diff + 1440; // 1440 = minutes in a day
  }

  String get durationLabel {
    final d = durationMinutes;
    if (d == null) return '—';
    final h = d ~/ 60;
    final m = d % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static int? _parseTime(String? t) {
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date.toIso8601String(),
        'sleep_time': sleepTime,
        'wake_time': wakeTime,
      };

  factory SleepEntry.fromMap(Map<String, dynamic> map) => SleepEntry(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        sleepTime: map['sleep_time'] as String?,
        wakeTime: map['wake_time'] as String?,
      );

  SleepEntry copyWith({
    int? id,
    DateTime? date,
    String? sleepTime,
    String? wakeTime,
  }) =>
      SleepEntry(
        id: id ?? this.id,
        date: date ?? this.date,
        sleepTime: sleepTime ?? this.sleepTime,
        wakeTime: wakeTime ?? this.wakeTime,
      );
}
