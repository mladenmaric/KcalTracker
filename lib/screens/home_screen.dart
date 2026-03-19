import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/food_item.dart';
import '../models/meal.dart';
import '../providers/meals_provider.dart';
import '../widgets/calorie_summary.dart';
import '../widgets/date_navigation.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final mealsAsync   = ref.watch(mealsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const DateNavigator(),
        actions: [
          // Calendar for jumping to a specific date
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Jump to date',
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
          // Overflow menu — keeps the AppBar uncluttered
          PopupMenuButton<_MenuAction>(
            onSelected: (action) {
              switch (action) {
                case _MenuAction.weeklyStats:
                  context.pushNamed('weekly-stats');
                case _MenuAction.goals:
                  context.pushNamed('goals');
                case _MenuAction.foodDatabase:
                  context.pushNamed('food-database');
                case _MenuAction.history:
                  context.pushNamed('history');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _MenuAction.weeklyStats,
                child: ListTile(
                  leading: Icon(Icons.bar_chart),
                  title: Text('Weekly Stats'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.goals,
                child: ListTile(
                  leading: Icon(Icons.track_changes),
                  title: Text('Goals'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.foodDatabase,
                child: ListTile(
                  leading: Icon(Icons.restaurant_menu),
                  title: Text('Food Database'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.history,
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('History'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const CalorieSummary(),
          Expanded(
            child: mealsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Error loading meals: $e')),
              data:    (meals) {
                if (meals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant_outlined,
                            size: 56,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No meals logged.',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text('Tap + to add one.',
                            style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: meals.length,
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    final timeLabel = DateFormat('HH:mm').format(meal.date);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ExpansionTile(
                        title: Text(meal.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
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
                              tooltip: 'Delete meal',
                              onPressed: () =>
                                  _confirmDeleteMeal(context, ref, meal),
                            ),
                          ],
                        ),
                        children: meal.foodItems.map((item) {
                          return Dismissible(
                            key: Key('food-item-${item.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) {
                              ref
                                  .read(mealsProvider.notifier)
                                  .deleteFoodItem(item.id!);
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${item.name} removed'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () {
                                      ref
                                          .read(mealsProvider.notifier)
                                          .addFoodItem(FoodItem(
                                            mealId: item.mealId,
                                            foodDefinitionId:
                                                item.foodDefinitionId,
                                            name: item.name,
                                            grams: item.grams,
                                            calories: item.calories,
                                            protein: item.protein,
                                            carbs: item.carbs,
                                            fat: item.fat,
                                          ));
                                    },
                                  ),
                                ),
                              );
                            },
                            child: ListTile(
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
                            ),
                          );
                        }).toList(),
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

enum _MenuAction { weeklyStats, goals, foodDatabase, history }

void _confirmDeleteMeal(BuildContext context, WidgetRef ref, Meal meal) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete meal?'),
      content: Text(
          'Delete "${meal.name}" and all its food items? This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () {
            ref.read(mealsProvider.notifier).deleteMeal(meal.id!);
            Navigator.pop(ctx);
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
