import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/goals.dart';
import '../models/meal_plan.dart';
import '../models/plan_item.dart';
import '../services/meal_plan_solver.dart';
import 'goals_provider.dart';
import 'meals_provider.dart';

/// Today's plan (null if none created yet).
final currentPlanProvider =
    AsyncNotifierProvider<CurrentPlanNotifier, MealPlan?>(
        CurrentPlanNotifier.new);

class CurrentPlanNotifier extends AsyncNotifier<MealPlan?> {
  @override
  Future<MealPlan?> build() async {
    final date = ref.watch(selectedDateProvider);
    return DatabaseHelper.instance.getMealPlanForDate(date);
  }

  /// Save a brand-new plan (items without optimal grams yet).
  Future<MealPlan> createPlan(String name, List<PlanItem> items) async {
    final date = ref.read(selectedDateProvider);
    final goals = ref.read(goalsProvider).value ?? const Goals();

    final plan = MealPlan(
      date: date,
      name: name,
      goalKcal: goals.dailyKcal,
      proteinGoalG: goals.proteinGrams,
      carbsGoalG: goals.carbsGrams,
      fatGoalG: goals.fatGrams,
    );

    final planId = await DatabaseHelper.instance.insertMealPlan(plan);
    final savedItems =
        items.map((i) => i.copyWith(planId: planId)).toList();
    await DatabaseHelper.instance.insertPlanItems(savedItems);

    ref.invalidateSelf();
    return plan.copyWith(id: planId, items: savedItems);
  }

  /// Run the LP solver, persist optimal grams, mark plan as solved.
  Future<void> solve(MealPlan plan) async {
    final result = MealPlanSolver.solve(
      items: plan.items,
      goalKcal: plan.goalKcal,
      goalProteinG: plan.proteinGoalG,
      goalCarbsG: plan.carbsGoalG,
      goalFatG: plan.fatGoalG,
    );

    // Persist each item's optimal grams
    for (int i = 0; i < plan.items.length; i++) {
      final itemId = plan.items[i].id;
      if (itemId != null) {
        await DatabaseHelper.instance.updatePlanItemOptimal(
            itemId, result.optimalGrams[i]);
      }
    }

    // Mark plan as solved
    final solved = plan.copyWith(isSolved: true);
    await DatabaseHelper.instance.updateMealPlan(solved);
    ref.invalidateSelf();
  }

  Future<void> deletePlan(int id) async {
    await DatabaseHelper.instance.deleteMealPlan(id);
    ref.invalidateSelf();
  }
}

/// All plans (for history screen).
final allPlansProvider =
    FutureProvider<List<MealPlan>>((ref) {
  return DatabaseHelper.instance.getAllMealPlans();
});
