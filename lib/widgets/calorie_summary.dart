import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/goals_provider.dart';
import '../providers/meals_provider.dart';

class CalorieSummary extends ConsumerWidget {
  const CalorieSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date       = ref.watch(selectedDateProvider);
    final mealsAsync = ref.watch(mealsProvider);
    final goalsAsync = ref.watch(goalsProvider);
    final total      = ref.watch(totalCaloriesProvider);

    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = date == today
        ? 'Today'
        : DateFormat('EEE, MMM d').format(date);

    final (protein, carbs, fat) = mealsAsync.when(
      data: (meals) {
        double p = 0, c = 0, f = 0;
        for (final meal in meals) {
          for (final item in meal.foodItems) {
            p += item.protein;
            c += item.carbs;
            f += item.fat;
          }
        }
        return (p, c, f);
      },
      loading: () => (0.0, 0.0, 0.0),
      error:   (_, _) => (0.0, 0.0, 0.0),
    );

    return goalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, _) => const SizedBox.shrink(),
      data:    (goals) {
        final progress  = goals.dailyKcal > 0
            ? (total / goals.dailyKcal).clamp(0.0, 1.5)
            : 0.0;
        final remaining = (goals.dailyKcal - total).clamp(0.0, goals.dailyKcal);
        final over      = total > goals.dailyKcal;
        final ringColor = over ? Colors.red : Colors.green;

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Label ────────────────────────────────────────────────
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 10),

                // ── Calorie ring + macro bars ─────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Ring
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(100, 100),
                            painter: _RingPainter(
                              progress: progress.clamp(0.0, 1.0),
                              color: ringColor,
                              bgColor: Colors.grey.shade200,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                total.toStringAsFixed(0),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: ringColor),
                              ),
                              Text(
                                'kcal',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Macro bars + calorie goal/remaining
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Goal / remaining chips
                          Row(
                            children: [
                              _CalChip(
                                label: 'Goal',
                                value:
                                    '${goals.dailyKcal.toStringAsFixed(0)} kcal',
                              ),
                              const SizedBox(width: 8),
                              _CalChip(
                                label: over ? 'Over' : 'Left',
                                value: over
                                    ? '+${(total - goals.dailyKcal).toStringAsFixed(0)} kcal'
                                    : '${remaining.toStringAsFixed(0)} kcal',
                                valueColor: over ? Colors.red : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),

                          // Macro rows
                          _MacroBar(
                            label: 'P',
                            eaten: protein,
                            goal: goals.proteinGrams,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 5),
                          _MacroBar(
                            label: 'C',
                            eaten: carbs,
                            goal: goals.carbsGrams,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(height: 5),
                          _MacroBar(
                            label: 'F',
                            eaten: fat,
                            goal: goals.fatGrams,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color  color;
  final Color  bgColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  static const _thickness = 10.0;
  static const _sweepDeg  = 270.0; // arc spans 270°, leaving a gap at bottom

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    final cy     = size.height / 2;
    final radius = (size.width / 2) - _thickness / 2;
    final rect   = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final bgPaint = Paint()
      ..color       = bgColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = _thickness
      ..strokeCap   = StrokeCap.round;

    final fgPaint = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = _thickness
      ..strokeCap   = StrokeCap.round;

    // Start at bottom-left of gap (135° = 7 o'clock position)
    final startRad = _degToRad(135);
    final sweepRad = _degToRad(_sweepDeg);

    canvas.drawArc(rect, startRad, sweepRad, false, bgPaint);
    if (progress > 0) {
      canvas.drawArc(
          rect, startRad, sweepRad * progress, false, fgPaint);
    }
  }

  double _degToRad(double deg) => deg * math.pi / 180;

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double eaten;
  final double goal;
  final Color  color;

  const _MacroBar({
    required this.label,
    required this.eaten,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = goal > 0 ? (eaten / goal).clamp(0.0, 1.0) : 0.0;
    final over = goal > 0 && eaten > goal;
    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              color: over ? Colors.red : color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 64,
          child: Text(
            '${eaten.toStringAsFixed(0)}/${goal.toStringAsFixed(0)}g',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _CalChip extends StatelessWidget {
  final String  label;
  final String  value;
  final Color?  valueColor;

  const _CalChip({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.grey.shade500),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      );
}
