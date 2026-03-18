import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food_definition.dart';
import '../services/food_api_service.dart';

// Holds the query the user has typed in the online search tab.
final onlineSearchQueryProvider = StateProvider<String>((ref) => '');

// Fires an API call whenever the query changes (debounced in the UI layer).
final onlineFoodSearchProvider =
    FutureProvider.autoDispose.family<List<FoodDefinition>, String>(
  (ref, query) => FoodApiService.instance.search(query),
);
