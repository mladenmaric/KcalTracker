import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/food_definition.dart';
import 'secrets.dart';

// USDA FoodData Central API
// Free government nutrition database with generic/common foods.
// Docs: https://app.swaggerhub.com/apis/fdcnal/food-data_central_api/1.0.1
//
// Get your free API key at: https://fdc.nal.usda.gov/api-guide.html
// Replace _apiKey below with your key to remove rate limits.
// DEMO_KEY limits: 30 requests/hour, 50/day.
class FoodApiService {
  FoodApiService._();
  static final FoodApiService instance = FoodApiService._();

  // ⚠️ Replace with your free key from https://fdc.nal.usda.gov/api-guide.html
  static const _apiKey = Secrets.usdaApiKey;
  static const _baseUrl = 'https://api.nal.usda.gov/fdc/v1';

  // Nutrient IDs used by USDA FoodData Central
  static const _idKcal    = 1008;
  static const _idProtein = 1003;
  static const _idCarbs   = 1005;
  static const _idFat     = 1004;

  Future<List<FoodDefinition>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/foods/search').replace(
      queryParameters: {
        'query': query,
        'api_key': _apiKey,
        // Foundation = raw/generic ingredients, SR Legacy = standard reference.
        // These two types give common everyday foods instead of branded products.
        'dataType': 'Foundation,SR Legacy',
        'pageSize': '25',
        'sortBy': 'score',
        'sortOrder': 'desc',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 429) {
      throw Exception('Rate limit reached. Get a free API key at fdc.nal.usda.gov');
    }
    if (response.statusCode != 200) {
      throw Exception('USDA API returned ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final foods = body['foods'] as List<dynamic>? ?? [];

    return foods
        .map((f) => _parseFood(f as Map<String, dynamic>))
        .whereType<FoodDefinition>() // removes nulls
        .toList();
  }

  FoodDefinition? _parseFood(Map<String, dynamic> f) {
    final name = f['description'] as String?;
    if (name == null || name.trim().isEmpty) return null;

    final nutrients = f['foodNutrients'] as List<dynamic>? ?? [];

    double? kcal, protein, carbs, fat;
    for (final n in nutrients) {
      final map = n as Map<String, dynamic>;
      final id    = map['nutrientId'] as int?;
      final value = _toDouble(map['value']);
      if (value == null) continue;
      switch (id) {
        case _idKcal:    kcal    = value;
        case _idProtein: protein = value;
        case _idCarbs:   carbs   = value;
        case _idFat:     fat     = value;
      }
    }

    if (kcal == null || kcal <= 0) return null;

    return FoodDefinition(
      name: _cleanName(name),
      caloriesPer100g: kcal,
      proteinPer100g:  protein ?? 0,
      carbsPer100g:    carbs   ?? 0,
      fatPer100g:      fat     ?? 0,
    );
  }

  // USDA names are ALL CAPS — convert to Title Case for readability.
  String _cleanName(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
