import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/food_definition.dart';

// Search query the user types in the food picker screen.
final foodSearchQueryProvider = StateProvider<String>((ref) => '');

// All food definitions, filtered by search query.
final foodDefinitionsProvider =
    AsyncNotifierProvider<FoodDefinitionsNotifier, List<FoodDefinition>>(
        FoodDefinitionsNotifier.new);

class FoodDefinitionsNotifier extends AsyncNotifier<List<FoodDefinition>> {
  @override
  Future<List<FoodDefinition>> build() async {
    final query = ref.watch(foodSearchQueryProvider);
    if (query.isEmpty) {
      return DatabaseHelper.instance.getAllFoodDefinitions();
    }
    return DatabaseHelper.instance.searchFoodDefinitions(query);
  }

  Future<void> add(FoodDefinition def) async {
    await DatabaseHelper.instance.insertFoodDefinition(def);
    ref.invalidateSelf();
  }

  Future<void> save(FoodDefinition def) async {
    await DatabaseHelper.instance.updateFoodDefinition(def);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await DatabaseHelper.instance.deleteFoodDefinition(id);
    ref.invalidateSelf();
  }
}
