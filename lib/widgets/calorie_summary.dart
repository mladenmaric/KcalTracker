import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/goals_provider.dart';
import '../providers/meals_provider.dart';

class CalorieSummary extends ConsumerWidget {
  const CalorieSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(mealsProvider);
    final goalsAsync = ref.watch(goalsProvider);

    final total = ref.watch(totalCaloriesProvider);

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
      error: (_, _) => (0.0, 0.0, 0.0),
    );

    return goalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (goals) {
        final remaining = (goals.dailyKcal - total).clamp(0.0, goals.dailyKcal);
        final kcalProgress = (total / goals.dailyKcal).clamp(0.0, 1.0);

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Today\'s Calories',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),

                // ── Calorie row ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(label: 'Eaten',  value: total.toStringAsFixed(0),               unit: 'kcal'),
                    _Stat(label: 'Goal',   value: goals.dailyKcal.toStringAsFixed(0),      unit: 'kcal'),
                    _Stat(label: 'Left',   value: remaining.toStringAsFixed(0),            unit: 'kcal'),
                  ],
                ),
                const SizedBox(height: 10),
                _ProgressBar(
                  value: kcalProgress,
                  color: kcalProgress >= 1.0 ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // ── Macro rows ──────────────────────────────────────────
                _MacroRow(
                  label: 'Protein',
                  eaten: protein,
                  goal: goals.proteinGrams,
                  color: Colors.blue,
                ),
                const SizedBox(height: 8),
                _MacroRow(
                  label: 'Carbs',
                  eaten: carbs,
                  goal: goals.carbsGrams,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(height: 8),
                _MacroRow(
                  label: 'Fat',
                  eaten: fat,
                  goal: goals.fatGrams,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final double eaten;
  final double goal;
  final Color color;

  const _MacroRow({
    required this.label,
    required this.eaten,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (eaten / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            Text(
              '${eaten.toStringAsFixed(1)}g / ${goal.toStringAsFixed(0)}g',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        _ProgressBar(value: progress, color: color),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 8,
          backgroundColor: Colors.grey.shade200,
          color: color,
        ),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _Stat({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
        ],
      );
}
