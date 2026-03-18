import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/meal_plan.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/meals_provider.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final planAsync = ref.watch(currentPlanProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Planner — ${DateFormat('MMM d').format(date)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Plan history',
            onPressed: () => context.pushNamed('plan-history'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) {
                ref.read(selectedDateProvider.notifier).state = picked;
              }
            },
          ),
        ],
      ),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (plan) => plan == null
            ? _EmptyState(date: date)
            : _PlanView(plan: plan),
      ),
      floatingActionButton: planAsync.when(
        data: (plan) => plan == null
            ? FloatingActionButton.extended(
                onPressed: () => context.pushNamed('create-plan'),
                icon: const Icon(Icons.add),
                label: const Text('Create Plan'),
              )
            : null,
        loading: () => null,
        error: (_, _) => null,
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final DateTime date;
  const _EmptyState({required this.date});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No plan for ${DateFormat('MMM d').format(date)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a meal plan to optimise your\ncalorie & macro intake.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
}

// ── Plan view (solved or unsolved) ───────────────────────────────────────────

class _PlanView extends ConsumerWidget {
  final MealPlan plan;
  const _PlanView({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byMeal = plan.byMeal;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Summary card ──────────────────────────────────────────────
        _SummaryCard(plan: plan),
        const SizedBox(height: 12),

        // ── Solve button (if not yet solved) ─────────────────────────
        if (!plan.isSolved)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Optimise with LP Solver'),
              onPressed: () =>
                  ref.read(currentPlanProvider.notifier).solve(plan),
            ),
          ),

        // ── Meals ─────────────────────────────────────────────────────
        for (final entry in byMeal.entries) ...[
          _MealSection(
              mealName: entry.key,
              items: entry.value,
              isSolved: plan.isSolved),
          const SizedBox(height: 8),
        ],

        // ── Delete plan ───────────────────────────────────────────────
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          label: const Text('Delete plan',
              style: TextStyle(color: Colors.red)),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete plan?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              ref
                  .read(currentPlanProvider.notifier)
                  .deletePlan(plan.id!);
            }
          },
        ),
      ],
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final MealPlan plan;
  const _SummaryCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final solved = plan.isSolved;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(plan.name,
                      style: Theme.of(context).textTheme.titleMedium)),
              Chip(
                label: Text(solved ? 'Optimised' : 'Draft'),
                backgroundColor: solved
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
              ),
            ]),
            const SizedBox(height: 12),
            _MacroRow('Calories', plan.totalKcal, plan.goalKcal, 'kcal',
                Colors.green),
            _MacroRow('Protein', plan.totalProtein, plan.proteinGoalG, 'g',
                Colors.blue),
            _MacroRow('Carbs', plan.totalCarbs, plan.carbsGoalG, 'g',
                Colors.amber.shade700),
            _MacroRow(
                'Fat', plan.totalFat, plan.fatGoalG, 'g', Colors.red),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final String unit;
  final Color color;

  const _MacroRow(
      this.label, this.value, this.goal, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: color)),
              Text(
                '${value.toStringAsFixed(1)} / ${goal.toStringAsFixed(0)} $unit',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: color,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meal section ──────────────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final String mealName;
  final List<dynamic> items;
  final bool isSolved;

  const _MealSection({
    required this.mealName,
    required this.items,
    required this.isSolved,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(mealName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${items.fold<double>(0, (s, i) => s + i.effectiveCalories).toStringAsFixed(0)} kcal',
        ),
        children: items.map<Widget>((item) {
          final grams = isSolved && item.optimalGrams != null
              ? item.optimalGrams!
              : (item.minGrams + item.maxGrams) / 2;

          return ListTile(
            dense: true,
            title: Text(item.foodName),
            subtitle: Text(
              isSolved
                  ? 'P ${item.effectiveProtein.toStringAsFixed(1)}g  '
                      'C ${item.effectiveCarbs.toStringAsFixed(1)}g  '
                      'F ${item.effectiveFat.toStringAsFixed(1)}g'
                  : 'Range: ${item.minGrams.toStringAsFixed(0)}–'
                      '${item.maxGrams.toStringAsFixed(0)}g',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${grams.toStringAsFixed(isSolved ? 1 : 0)}g',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSolved
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),
                Text(
                  '${item.effectiveCalories.toStringAsFixed(0)} kcal',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
