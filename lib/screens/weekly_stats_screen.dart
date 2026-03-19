import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/meal.dart';
import '../models/sleep_entry.dart';
import '../models/training_entry.dart';
import '../models/weight_entry.dart';
import '../providers/goals_provider.dart';

// ── Macro colour constants — match calorie_summary.dart on home screen ────────
const _kColorCalories = Colors.green;
const _kColorProtein  = Colors.blue;
const Color _kColorCarbs = Color(0xFFF57F17); // Colors.amber.shade700
const _kColorFat      = Colors.red;

// ── Data holder loaded in a single Future.wait ───────────────────────────────
typedef _WeekData = ({
  List<Meal>          meals,
  List<SleepEntry>    sleep,
  List<TrainingEntry> training,
  List<WeightEntry>   weight,
});

class WeeklyStatsScreen extends ConsumerStatefulWidget {
  const WeeklyStatsScreen({super.key});

  @override
  ConsumerState<WeeklyStatsScreen> createState() => _WeeklyStatsScreenState();
}

class _WeeklyStatsScreenState extends ConsumerState<WeeklyStatsScreen> {
  int _weekOffset = 0;

  DateTime get _weekStart {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mon   = today.subtract(Duration(days: today.weekday - 1));
    return mon.add(Duration(days: 7 * _weekOffset));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  Future<_WeekData> _fetchAll() async {
    final db = DatabaseHelper.instance;
    final results = await Future.wait([
      db.getMealsForDateRange(_weekStart, _weekEnd),
      db.getSleepForDateRange(_weekStart, _weekEnd),
      db.getTrainingForDateRange(_weekStart, _weekEnd),
      db.getWeightForDateRange(_weekStart, _weekEnd),
    ]);
    return (
      meals:    results[0] as List<Meal>,
      sleep:    results[1] as List<SleepEntry>,
      training: results[2] as List<TrainingEntry>,
      weight:   results[3] as List<WeightEntry>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);
    final weekFmt    = DateFormat('MMM d');

    return Scaffold(
      appBar: AppBar(
        title: Text('${weekFmt.format(_weekStart)} – ${weekFmt.format(_weekEnd)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous week',
            onPressed: () => setState(() => _weekOffset--),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next week',
            onPressed: _weekOffset == 0
                ? null
                : () => setState(() => _weekOffset++),
          ),
        ],
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (goals) => FutureBuilder<_WeekData>(
          future: _fetchAll(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!;
            final days = List.generate(
                7, (i) => _weekStart.add(Duration(days: i)));
            final now   = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            // ── Per-day nutrition ─────────────────────────────────────
            final dayNutr = days.map((day) {
              final ds = day.toIso8601String().substring(0, 10);
              final ms = data.meals.where(
                  (m) => m.date.toIso8601String().substring(0, 10) == ds);
              return (
                day:     day,
                kcal:    ms.fold(0.0, (s, m) => s + m.totalCalories),
                protein: ms.fold(0.0, (s, m) => s + m.foodItems.fold(
                    0.0, (ss, fi) => ss + fi.protein)),
                carbs:   ms.fold(0.0, (s, m) => s + m.foodItems.fold(
                    0.0, (ss, fi) => ss + fi.carbs)),
                fat:     ms.fold(0.0, (s, m) => s + m.foodItems.fold(
                    0.0, (ss, fi) => ss + fi.fat)),
              );
            }).toList();

            final totalKcal    = dayNutr.fold(0.0, (s, d) => s + d.kcal);
            final totalProtein = dayNutr.fold(0.0, (s, d) => s + d.protein);
            final totalCarbs   = dayNutr.fold(0.0, (s, d) => s + d.carbs);
            final totalFat     = dayNutr.fold(0.0, (s, d) => s + d.fat);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 1. Weekly nutrition summary ───────────────────────
                _SectionHeader('Nutrition'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _MacroRow(
                          label:  'Calories',
                          actual: totalKcal,
                          goal:   goals.dailyKcal * 7,
                          unit:   'kcal',
                          color:  _kColorCalories,
                        ),
                        const SizedBox(height: 10),
                        _MacroRow(
                          label:  'Protein',
                          actual: totalProtein,
                          goal:   goals.proteinGrams * 7,
                          unit:   'g',
                          color:  _kColorProtein,
                        ),
                        const SizedBox(height: 10),
                        _MacroRow(
                          label:  'Carbs',
                          actual: totalCarbs,
                          goal:   goals.carbsGrams * 7,
                          unit:   'g',
                          color:  _kColorCarbs,
                        ),
                        const SizedBox(height: 10),
                        _MacroRow(
                          label:  'Fat',
                          actual: totalFat,
                          goal:   goals.fatGrams * 7,
                          unit:   'g',
                          color:  _kColorFat,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 2. Daily breakdown ────────────────────────────────
                _SectionHeader('Daily Breakdown'),
                ...dayNutr.map((d) {
                  final isToday  = d.day == today;
                  final isFuture = d.day.isAfter(today);
                  final progress = goals.dailyKcal > 0
                      ? d.kcal / goals.dailyKcal
                      : 0.0;
                  final barColor = d.kcal == 0
                      ? Colors.grey.shade300
                      : (progress > 1.05 ? Colors.red : Colors.green);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isToday
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('EEE, MMM d').format(d.day),
                                style: TextStyle(
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              if (isFuture)
                                Text('—',
                                    style: TextStyle(
                                        color: Colors.grey.shade400))
                              else if (d.kcal == 0)
                                Text('No data',
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 12))
                              else
                                Text(
                                  '${d.kcal.toStringAsFixed(0)} / '
                                  '${goals.dailyKcal.toStringAsFixed(0)} kcal',
                                  style: TextStyle(
                                    color: progress > 1.05
                                        ? Colors.red
                                        : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          if (!isFuture && d.kcal > 0) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                backgroundColor: Colors.grey.shade200,
                                valueColor:
                                    AlwaysStoppedAnimation(barColor),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                              children: [
                                _MiniMacro('Protein', d.protein,
                                    _kColorProtein),
                                _MiniMacro(
                                    'Carbs', d.carbs, _kColorCarbs),
                                _MiniMacro('Fat', d.fat, _kColorFat),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 4),

                // ── 3. Weight ─────────────────────────────────────────
                _SectionHeader('Weight'),
                _WeightSection(
                    entries: data.weight, days: days, today: today),
                const SizedBox(height: 12),

                // ── 4. Sleep ──────────────────────────────────────────
                _SectionHeader('Sleep'),
                _SleepSection(entries: data.sleep, days: days),
                const SizedBox(height: 12),

                // ── 5. Training ───────────────────────────────────────
                _SectionHeader('Training'),
                _TrainingSection(entries: data.training),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Section widgets ───────────────────────────────────────────────────────────

class _WeightSection extends StatelessWidget {
  final List<WeightEntry> entries;
  final List<DateTime>    days;
  final DateTime          today;

  const _WeightSection({
    required this.entries,
    required this.days,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyCard('No weight logged this week.');
    }

    // Build per-day nullable weights
    final pts = days.map((d) {
      final ds = d.toIso8601String().substring(0, 10);
      final e = entries.where(
          (e) => e.date.toIso8601String().substring(0, 10) == ds);
      return e.isEmpty ? null : e.first.weightKg;
    }).toList();

    final min = entries.map((e) => e.weightKg).reduce(math.min);
    final max = entries.map((e) => e.weightKg).reduce(math.max);
    final delta = max - min;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: _WeightChart(points: pts, minKg: min, maxKg: max),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip('Start',
                    '${entries.first.weightKg.toStringAsFixed(1)} kg'),
                _StatChip('End',
                    '${entries.last.weightKg.toStringAsFixed(1)} kg'),
                _StatChip(
                  'Change',
                  delta == 0
                      ? '0.0 kg'
                      : '${entries.last.weightKg - entries.first.weightKg > 0 ? '+' : ''}'
                          '${(entries.last.weightKg - entries.first.weightKg).toStringAsFixed(1)} kg',
                  color: entries.last.weightKg <= entries.first.weightKg
                      ? Colors.green
                      : Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<double?> points; // 7 nullable values (Mon–Sun)
  final double        minKg;
  final double        maxKg;

  const _WeightChart(
      {required this.points, required this.minKg, required this.maxKg});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return CustomPaint(
      painter: _WeightChartPainter(
        points: points,
        minKg:  minKg,
        maxKg:  maxKg,
        color:  color,
        labelStyle: Theme.of(context).textTheme.labelSmall!,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<double?> points;
  final double        minKg;
  final double        maxKg;
  final Color         color;
  final TextStyle     labelStyle;

  static const _bottomPad = 20.0;
  static const _topPad    = 16.0;
  static const _leftPad   = 4.0;

  _WeightChartPainter({
    required this.points,
    required this.minKg,
    required this.maxKg,
    required this.color,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartH = size.height - _topPad - _bottomPad;
    final range  = (maxKg - minKg).abs() < 0.1 ? 1.0 : maxKg - minKg;
    final step   = (size.width - _leftPad) / 7;
    final days   = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = color;
    final emptyDotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Grid lines
    for (var i = 0; i <= 4; i++) {
      final y = _topPad + chartH * (1 - i / 4);
      canvas.drawLine(
          Offset(_leftPad, y), Offset(size.width, y), gridPaint);
    }

    // Day labels
    for (var i = 0; i < 7; i++) {
      final x = _leftPad + i * step + step / 2;
      final tp = TextPainter(
        text: TextSpan(text: days[i], style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - tp.height));
    }

    // Collect pixel positions for existing points
    final pixelPts = <int, Offset>{};
    for (var i = 0; i < 7; i++) {
      final v = points[i];
      if (v != null) {
        final x = _leftPad + i * step + step / 2;
        final y = _topPad + chartH * (1 - (v - minKg) / range);
        pixelPts[i] = Offset(x, y);
      }
    }

    // Lines between consecutive data points
    final idxs = pixelPts.keys.toList()..sort();
    for (var k = 0; k < idxs.length - 1; k++) {
      final a = pixelPts[idxs[k]]!;
      final b = pixelPts[idxs[k + 1]]!;
      canvas.drawLine(a, b, linePaint);
    }

    // Dots + value labels
    for (final i in idxs) {
      final pt = pixelPts[i]!;
      canvas.drawCircle(pt, 4, dotPaint);

      // Weight label above dot
      final label = points[i]!.toStringAsFixed(1);
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: labelStyle.copyWith(
                color: color, fontWeight: FontWeight.w600)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - tp.height - 4));
    }

    // Empty day dots (ghost)
    for (var i = 0; i < 7; i++) {
      if (points[i] == null) {
        final x = _leftPad + i * step + step / 2;
        final y = _topPad + chartH * 0.5;
        canvas.drawCircle(Offset(x, y), 3, emptyDotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) =>
      old.points != points || old.minKg != minKg || old.maxKg != maxKg;
}

class _SleepSection extends StatelessWidget {
  final List<SleepEntry> entries;
  final List<DateTime>   days;

  const _SleepSection({required this.entries, required this.days});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyCard('No sleep logged this week.');
    }

    final durations = entries
        .map((e) => e.durationMinutes)
        .whereType<int>()
        .toList();

    if (durations.isEmpty) {
      return _EmptyCard('Sleep times incomplete — check your entries.');
    }

    final avgMin  = durations.reduce((a, b) => a + b) ~/ durations.length;
    final bestMin = durations.reduce(math.max);
    final worstMin = durations.reduce(math.min);
    final maxMin   = durations.reduce(math.max).toDouble();

    String fmt(int m) {
      final h = m ~/ 60;
      final mm = m % 60;
      return mm == 0 ? '${h}h' : '${h}h ${mm}m';
    }

    // Per-day map
    final dayDur = <String, int?>{};
    for (final day in days) {
      final ds = day.toIso8601String().substring(0, 10);
      final e = entries.where(
          (e) => e.date.toIso8601String().substring(0, 10) == ds);
      dayDur[ds] = e.isEmpty ? null : e.first.durationMinutes;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip('Avg / night', fmt(avgMin)),
                _StatChip('Best', fmt(bestMin), color: Colors.green),
                _StatChip('Worst', fmt(worstMin),
                    color: worstMin < 360 ? Colors.red : null),
                _StatChip('Logged', '${durations.length}/7'),
              ],
            ),
            const SizedBox(height: 14),
            // Per-day bars
            ...days.map((day) {
              final ds  = day.toIso8601String().substring(0, 10);
              final dur = dayDur[ds];
              final pct = dur != null && maxMin > 0
                  ? (dur / maxMin).clamp(0.0, 1.0)
                  : 0.0;
              final barColor = dur == null
                  ? Colors.grey.shade200
                  : (dur < 360
                      ? Colors.red
                      : dur < 420
                          ? Colors.orange
                          : Colors.indigo.shade300);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        DateFormat('E').format(day).substring(0, 2),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation(barColor),
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      child: Text(
                        dur != null ? fmt(dur) : '—',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TrainingSection extends StatelessWidget {
  final List<TrainingEntry> entries;

  const _TrainingSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyCard('No training logged this week.');
    }

    final totalMin = entries.fold(0, (s, e) => s + e.durationMinutes);
    final sessions = entries.length;
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    final totalLabel = h > 0 ? (m > 0 ? '${h}h ${m}m' : '${h}h') : '${m}m';

    // Group by type
    final byType = <String, int>{};
    for (final e in entries) {
      byType[e.type] = (byType[e.type] ?? 0) + e.durationMinutes;
    }
    final sorted = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxTypeMin = sorted.first.value.toDouble();

    final typeColors = [
      Colors.purple,
      Colors.indigo,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.amber,
      Colors.deepOrange,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip('Sessions', '$sessions'),
                _StatChip('Total time', totalLabel),
                _StatChip('Avg / session',
                    '${(totalMin / sessions).round()} min'),
              ],
            ),
            const SizedBox(height: 14),
            // Per-type bars
            ...sorted.asMap().entries.map((entry) {
              final i    = entry.key;
              final type = entry.value.key;
              final min  = entry.value.value;
              final pct  = (min / maxTypeMin).clamp(0.0, 1.0);
              final col  = typeColors[i % typeColors.length];
              final th = min ~/ 60;
              final tm = min % 60;
              final label = th > 0
                  ? (tm > 0 ? '${th}h ${tm}m' : '${th}h')
                  : '${tm}m';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(type,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation(col),
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(label,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message,
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ),
      );
}

class _StatChip extends StatelessWidget {
  final String  label;
  final String  value;
  final Color?  color;

  const _StatChip(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.grey.shade500)),
        ],
      );
}

class _MacroRow extends StatelessWidget {
  final String label;
  final double actual;
  final double goal;
  final String unit;
  final Color  color;

  const _MacroRow({
    required this.label,
    required this.actual,
    required this.goal,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct  = goal > 0 ? (actual / goal).clamp(0.0, 1.0) : 0.0;
    final over = goal > 0 && actual > goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              '${actual.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit',
              style: TextStyle(
                fontSize: 12,
                color: over ? Colors.red : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
                over ? Colors.red : color.withValues(alpha: 0.85)),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _MiniMacro extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;

  const _MiniMacro(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('$label ${value.toStringAsFixed(1)}g',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
