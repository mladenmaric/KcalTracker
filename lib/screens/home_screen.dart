import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/meals_provider.dart';
import '../widgets/calorie_summary.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final mealsAsync = ref.watch(mealsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEE, MMM d').format(selectedDate)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Weekly stats',
            onPressed: () => context.pushNamed('weekly-stats'),
          ),
          IconButton(
            icon: const Icon(Icons.track_changes),
            tooltip: 'Goals',
            onPressed: () => context.pushNamed('goals'),
          ),
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Food database',
            onPressed: () => context.pushNamed('food-database'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.pushNamed('history'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                ref.read(selectedDateProvider.notifier).state = picked;
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const CalorieSummary(),
          Expanded(
            child: mealsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading meals: $e')),
              data: (meals) {
                if (meals.isEmpty) {
                  return const Center(
                    child: Text(
                      'No meals yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: meals.length,
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    // Show time if it's not midnight (i.e. user set a time).
                    final timeLabel =
                        DateFormat('HH:mm').format(meal.date);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ExpansionTile(
                        title: Text(meal.name),
                        subtitle: Text(
                          '$timeLabel  ·  '
                          '${meal.totalCalories.toStringAsFixed(0)} kcal',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Add food',
                              onPressed: () => context.pushNamed(
                                'add-food-item',
                                pathParameters: {
                                  'mealId': meal.id!.toString()
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref
                                  .read(mealsProvider.notifier)
                                  .deleteMeal(meal.id!),
                            ),
                          ],
                        ),
                        children: [
                          ...meal.foodItems.map(
                            (item) => ListTile(
                              dense: true,
                              title: Text(item.name),
                              subtitle: Text(
                                '${item.grams.toStringAsFixed(0)}g  '
                                '| P ${item.protein.toStringAsFixed(1)}g  '
                                '| C ${item.carbs.toStringAsFixed(1)}g  '
                                '| F ${item.fat.toStringAsFixed(1)}g',
                              ),
                              trailing: Text(
                                '${item.calories.toStringAsFixed(0)} kcal',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              leading: IconButton(
                                icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 18),
                                onPressed: () => ref
                                    .read(mealsProvider.notifier)
                                    .deleteFoodItem(item.id!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('add-meal'),
        icon: const Icon(Icons.add),
        label: const Text('Add Meal'),
      ),
    );
  }
}
