import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/food_item.dart';
import '../models/meal.dart';

// selectedDateProvider holds the date the user is currently viewing.
// Changing this date causes mealsProvider to re-fetch automatically.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day); // midnight = "today"
});

// mealsProvider fetches all meals (with food items) for the selected date.
// It is an AsyncNotifier so we can also mutate the list (add/delete).
final mealsProvider =
    AsyncNotifierProvider<MealsNotifier, List<Meal>>(MealsNotifier.new);

class MealsNotifier extends AsyncNotifier<List<Meal>> {
  @override
  Future<List<Meal>> build() async {
    // Re-run whenever selectedDate changes.
    final date = ref.watch(selectedDateProvider);
    return DatabaseHelper.instance.getMealsForDate(date);
  }

  // Add a new meal (without food items yet) and refresh.
  Future<Meal> addMeal(String name, DateTime dateTime) async {
    final meal = Meal(name: name, date: dateTime);
    final id = await DatabaseHelper.instance.insertMeal(meal);
    final created = meal.copyWith(id: id);
    // Optimistically update state.
    state = AsyncData([...state.value ?? [], created]);
    return created;
  }

  // Add a food item to an existing meal and refresh.
  Future<void> addFoodItem(FoodItem item) async {
    await DatabaseHelper.instance.insertFoodItem(item);
    // Full reload so totals are recalculated.
    ref.invalidateSelf();
  }

  // Delete a meal and all its food items.
  Future<void> deleteMeal(int mealId) async {
    await DatabaseHelper.instance.deleteMeal(mealId);
    ref.invalidateSelf();
  }

  // Delete a single food item.
  Future<void> deleteFoodItem(int foodItemId) async {
    await DatabaseHelper.instance.deleteFoodItem(foodItemId);
    ref.invalidateSelf();
  }
}

// Derived provider: total calories for the selected day.
final totalCaloriesProvider = Provider<double>((ref) {
  final mealsAsync = ref.watch(mealsProvider);
  return mealsAsync.when(
    data: (meals) => meals.fold(0.0, (sum, m) => sum + m.totalCalories),
    loading: () => 0.0,
    error: (_, _) => 0.0,
  );
});
