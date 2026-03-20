import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_item.dart';
import '../models/meal.dart';
import 'auth_provider.dart';

// selectedDateProvider holds the date the user is currently viewing.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final mealsProvider =
    AsyncNotifierProvider<MealsNotifier, List<Meal>>(MealsNotifier.new);

class MealsNotifier extends AsyncNotifier<List<Meal>> {
  SupabaseClient get _db  => Supabase.instance.client;
  String         get _uid => _db.auth.currentUser!.id;

  @override
  Future<List<Meal>> build() async {
    // Re-fetch whenever the logged-in user changes (e.g. after account switch).
    ref.watch(currentUserProvider);
    final date  = ref.watch(selectedDateProvider);
    final start = DateTime(date.year, date.month, date.day);
    final end   = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final data = await _db
        .from('meals')
        .select('*, food_items(*)')
        .eq('user_id', _uid)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String())
        .order('date');

    return data.map<Meal>((m) {
      final items = (m['food_items'] as List)
          .map((fi) => FoodItem.fromMap(fi as Map<String, dynamic>))
          .toList();
      return Meal.fromMap(m).copyWith(foodItems: items);
    }).toList();
  }

  Future<Meal> addMeal(String name, DateTime dateTime) async {
    final data = await _db
        .from('meals')
        .insert({'user_id': _uid, 'name': name, 'date': dateTime.toIso8601String()})
        .select()
        .single();
    final meal = Meal.fromMap(data).copyWith(foodItems: []);
    state = AsyncData([...state.value ?? [], meal]);
    return meal;
  }

  Future<void> addFoodItem(FoodItem item) async {
    final map = item.toMap()..remove('id');
    await _db.from('food_items').insert(map);
    ref.invalidateSelf();
  }

  Future<void> deleteMeal(int mealId) async {
    await _db.from('meals').delete().eq('id', mealId);
    ref.invalidateSelf();
  }

  Future<void> deleteFoodItem(int foodItemId) async {
    await _db.from('food_items').delete().eq('id', foodItemId);
    ref.invalidateSelf();
  }
}

final totalCaloriesProvider = Provider<double>((ref) {
  return ref.watch(mealsProvider).when(
    data:    (meals) => meals.fold(0.0, (s, m) => s + m.totalCalories),
    loading: () => 0.0,
    error:   (_, _) => 0.0,
  );
});
