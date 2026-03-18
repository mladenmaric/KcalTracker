import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/meal_plan.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/meals_provider.dart';

class PlanHistoryScreen extends ConsumerWidget {
  const PlanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(allPlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan History')),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (plans) {
          if (plans.isEmpty) {
            return const Center(
              child: Text('No plans yet.',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: plans.length,
            itemBuilder: (context, i) =>
                _PlanTile(plan: plans[i], ref: ref),
          );
        },
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final MealPlan plan;
  final WidgetRef ref;
  const _PlanTile({required this.plan, required this.ref});

  @override
  Widget build(BuildContext context) {
    final meals = plan.byMeal.keys.join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: plan.isSolved
              ? Colors.green.shade100
              : Colors.orange.shade100,
          child: Icon(
            plan.isSolved ? Icons.check : Icons.pending_outlined,
            color: plan.isSolved ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(plan.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEE, MMM d yyyy').format(plan.date)),
            Text(
              '${plan.totalKcal.toStringAsFixed(0)} kcal  '
              '| ${plan.items.length} foods  '
              '| $meals',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new, size: 18),
          tooltip: 'Jump to this day',
          onPressed: () {
            ref.read(selectedDateProvider.notifier).state = plan.date;
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
