import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_item.dart';
import '../models/meal.dart';
import '../providers/auth_provider.dart';
import '../providers/meals_provider.dart';
import '../providers/trainer_provider.dart';
import '../widgets/calorie_summary.dart';
import '../widgets/date_navigation.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate  = ref.watch(selectedDateProvider);
    final mealsAsync    = ref.watch(mealsProvider);
    final profileAsync  = ref.watch(profileProvider);

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
            onSelected: (action) async {
              switch (action) {
                case _MenuAction.weeklyStats:
                  context.pushNamed('weekly-stats');
                case _MenuAction.goals:
                  context.pushNamed('goals');
                case _MenuAction.foodDatabase:
                  context.pushNamed('food-database');
                case _MenuAction.history:
                  context.pushNamed('history');
                case _MenuAction.adminPanel:
                  context.pushNamed('admin');
                case _MenuAction.myAthletes:
                  context.pushNamed('trainer');
                case _MenuAction.signOut:
                  await Supabase.instance.client.auth.signOut();
              }
            },
            itemBuilder: (_) {
              final profile = profileAsync.valueOrNull;
              return [
                const PopupMenuItem(
                  value: _MenuAction.weeklyStats,
                  child: ListTile(
                    leading: Icon(Icons.bar_chart),
                    title: Text('Weekly Stats'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: _MenuAction.goals,
                  child: ListTile(
                    leading: Icon(Icons.track_changes),
                    title: Text('Goals'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: _MenuAction.foodDatabase,
                  child: ListTile(
                    leading: Icon(Icons.restaurant_menu),
                    title: Text('Food Database'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: _MenuAction.history,
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('History'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (profile?.isAdmin == true)
                  const PopupMenuItem(
                    value: _MenuAction.adminPanel,
                    child: ListTile(
                      leading: Icon(Icons.admin_panel_settings),
                      title: Text('Admin Panel'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (profile?.isTrainer == true)
                  const PopupMenuItem(
                    value: _MenuAction.myAthletes,
                    child: ListTile(
                      leading: Icon(Icons.people_outline),
                      title: Text('My Athletes'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: _MenuAction.signOut,
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Sign Out'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          profileAsync.whenData((p) => p?.displayName).valueOrNull != null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Hey, ${profileAsync.value!.displayName} 👋',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
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
                        children: [
                          ...meal.foodItems.map((item) => Dismissible(
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
                              )),
                          _TrainerCommentBubble(mealId: meal.id!),
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

enum _MenuAction { weeklyStats, goals, foodDatabase, history, adminPanel, myAthletes, signOut }

// ── Trainer comment bubble (read-only, shown inside each meal card) ──────────

class _TrainerCommentBubble extends ConsumerWidget {
  final int mealId;
  const _TrainerCommentBubble({required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(mealCommentsProvider(mealId));

    return commentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, _) => const SizedBox.shrink(),
      data:    (comments) {
        if (comments.isEmpty) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Column(
          children: comments.map((c) => Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.secondary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sports, size: 18, color: cs.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.trainerName ?? 'Trainer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.secondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(c.body, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        );
      },
    );
  }
}

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
