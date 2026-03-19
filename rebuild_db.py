import re

# Read food data
foods_lines = open('C:/Users/Mladen/AppData/Local/Temp/all_foods.txt', encoding='utf-8').readlines()
seen = set()
food_rows = []
for line in foods_lines:
    line = line.strip()
    m = re.match(r"^\('(.+)', ([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)$", line)
    if not m:
        continue
    name, kcal, p, c, f = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
    key = name.lower()
    if key in seen:
        continue
    seen.add(key)
    nd = name.replace("'", "\\'")
    food_rows.append(f"      ('{nd}', {kcal}, {p}, {c}, {f}),")

serbian_foods = '\n'.join(food_rows)

dart_content = """\
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/food_definition.dart';
import '../models/food_item.dart';
import '../models/meal.dart';
import '../models/meal_plan.dart';
import '../models/plan_item.dart';
import '../models/sleep_entry.dart';
import '../models/training_entry.dart';
import '../models/weight_entry.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kcal_tracker.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createFoodTables(db);
    await _createTrackingTables(db);
    await _createPlannerTables(db);
    await _seedFoodDefinitions(db);
    await _seedSerbianFoods(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS food_items');
      await _createFoodTables(db);
      await _seedFoodDefinitions(db);
    }
    if (oldVersion < 3) {
      await _createTrackingTables(db);
    }
    if (oldVersion < 4) {
      await _createPlannerTables(db);
    }
    if (oldVersion < 5) {
      await _seedSerbianFoods(db);
    }
  }

  Future<void> _createPlannerTables(Database db) async {
    await db.execute(\'\'\'
      CREATE TABLE IF NOT EXISTS meal_plans (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        date             TEXT    NOT NULL,
        name             TEXT    NOT NULL,
        goal_kcal        REAL    NOT NULL,
        protein_goal_g   REAL    NOT NULL,
        carbs_goal_g     REAL    NOT NULL,
        fat_goal_g       REAL    NOT NULL,
        is_solved        INTEGER NOT NULL DEFAULT 0
      )
    \'\'\');
    await db.execute(\'\'\'
      CREATE TABLE IF NOT EXISTS plan_items (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id              INTEGER NOT NULL REFERENCES meal_plans(id) ON DELETE CASCADE,
        meal_name            TEXT    NOT NULL,
        food_definition_id   INTEGER NOT NULL,
        food_name            TEXT    NOT NULL,
        min_grams            REAL    NOT NULL,
        max_grams            REAL    NOT NULL,
        optimal_grams        REAL,
        calories_per_100g    REAL    NOT NULL,
        protein_per_100g     REAL    NOT NULL,
        carbs_per_100g       REAL    NOT NULL,
        fat_per_100g         REAL    NOT NULL
      )
    \'\'\');
  }

  Future<void> _createFoodTables(Database db) async {
    await db.execute(\'\'\'
      CREATE TABLE IF NOT EXISTS food_definitions (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        name              TEXT    NOT NULL,
        calories_per_100g REAL    NOT NULL,
        protein_per_100g  REAL    NOT NULL,
        carbs_per_100g    REAL    NOT NULL,
        fat_per_100g      REAL    NOT NULL
      )
    \'\'\');
    await db.execute(\'\'\'
      CREATE TABLE IF NOT EXISTS meals (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT    NOT NULL,
        date  TEXT    NOT NULL
      )
    \'\'\');
    await db.execute(\'\'\'
      CREATE TABLE IF NOT EXISTS food_items (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id              INTEGER NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
        food_definition_id   INTEGER NOT NULL REFERENCES food_definitions(id),
        name                 TEXT    NOT NULL,
        grams                REAL    NOT NULL,
        calories             REAL    NOT NULL,
        protein              REAL    NOT NULL,
        carbs                REAL    NOT NULL,
        fat                  REAL    NOT NULL
      )
    \'\'\');
  }

  Future<void> _createTrackingTables(Database db) async {
    await db.execute(\'\'\'
      CREATE TABLE IF NOT EXISTS sleep_entries (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        date        TEXT    NOT NULL UNIQUE,
        sleep_time  TEXT,
        wake_time   TEXT
      )
    \'\'\');
    await db.execute(\'\'\'
      CREATE TABLE IF NOT EXISTS weight_entries (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        date       TEXT    NOT NULL,
        weight_kg  REAL    NOT NULL
      )
    \'\'\');
    await db.execute(\'\'\'
      CREATE TABLE IF NOT EXISTS training_entries (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        date              TEXT    NOT NULL,
        type              TEXT    NOT NULL,
        duration_minutes  INTEGER NOT NULL,
        notes             TEXT
      )
    \'\'\');
  }

  // \u2500\u2500 Seed data \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  Future<void> _seedFoodDefinitions(Database db) async {
    final foods = [
      ('Chicken Breast', 165.0, 31.0, 0.0, 3.6),
      ('Beef (ground, lean)', 215.0, 26.0, 0.0, 12.0),
      ('Salmon', 208.0, 20.0, 0.0, 13.0),
      ('Tuna (canned in water)', 116.0, 26.0, 0.0, 1.0),
      ('Eggs', 155.0, 13.0, 1.1, 11.0),
      ('Greek Yogurt', 59.0, 10.0, 3.6, 0.4),
      ('Cottage Cheese', 98.0, 11.0, 3.4, 4.3),
      ('White Rice (cooked)', 130.0, 2.7, 28.0, 0.3),
      ('Brown Rice (cooked)', 123.0, 2.6, 26.0, 1.0),
      ('Oats', 389.0, 17.0, 66.0, 7.0),
      ('Whole Wheat Bread', 247.0, 13.0, 41.0, 3.4),
      ('Potato (boiled)', 87.0, 1.9, 20.0, 0.1),
      ('Sweet Potato (boiled)', 90.0, 2.0, 21.0, 0.1),
      ('Pasta (cooked)', 158.0, 5.8, 31.0, 0.9),
      ('Banana', 89.0, 1.1, 23.0, 0.3),
      ('Apple', 52.0, 0.3, 14.0, 0.2),
      ('Olive Oil', 884.0, 0.0, 0.0, 100.0),
      ('Avocado', 160.0, 2.0, 9.0, 15.0),
      ('Almonds', 579.0, 21.0, 22.0, 50.0),
      ('Broccoli', 34.0, 2.8, 7.0, 0.4),
      ('Spinach', 23.0, 2.9, 3.6, 0.4),
    ];
    final batch = db.batch();
    for (final (name, kcal, protein, carbs, fat) in foods) {
      batch.insert('food_definitions', {
        'name': name,
        'calories_per_100g': kcal,
        'protein_per_100g': protein,
        'carbs_per_100g': carbs,
        'fat_per_100g': fat,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedSerbianFoods(Database db) async {
    final foods = [
SERBIAN_FOODS
    ];
    final batch = db.batch();
    for (final (name, kcal, protein, carbs, fat) in foods) {
      batch.insert('food_definitions', {
        'name': name,
        'calories_per_100g': kcal,
        'protein_per_100g': protein,
        'carbs_per_100g': carbs,
        'fat_per_100g': fat,
      });
    }
    await batch.commit(noResult: true);
  }

  // \u2500\u2500 Food definitions \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  Future<List<FoodDefinition>> getAllFoodDefinitions() async {
    final db = await database;
    final rows = await db.query('food_definitions', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(FoodDefinition.fromMap).toList();
  }

  Future<List<FoodDefinition>> searchFoodDefinitions(String query) async {
    final db = await database;
    final rows = await db.query(
      'food_definitions',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(FoodDefinition.fromMap).toList();
  }

  Future<int> insertFoodDefinition(FoodDefinition def) async {
    final db = await database;
    return db.insert('food_definitions', def.toMap());
  }

  Future<void> updateFoodDefinition(FoodDefinition def) async {
    final db = await database;
    await db.update('food_definitions', def.toMap(), where: 'id = ?', whereArgs: [def.id]);
  }

  Future<void> deleteFoodDefinition(int id) async {
    final db = await database;
    await db.delete('food_definitions', where: 'id = ?', whereArgs: [id]);
  }

  // \u2500\u2500 Meals \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  Future<int> insertMeal(Meal meal) async {
    final db = await database;
    return db.insert('meals', meal.toMap());
  }

  Future<List<Meal>> getMealsForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('meals', where: 'date LIKE ?', whereArgs: ['\$dateStr%'], orderBy: 'date ASC');
    final meals = <Meal>[];
    for (final row in rows) {
      final meal = Meal.fromMap(row);
      final items = await getFoodItemsForMeal(meal.id!);
      meals.add(meal.copyWith(foodItems: items));
    }
    return meals;
  }

  Future<void> deleteMeal(int id) async {
    final db = await database;
    await db.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  // \u2500\u2500 Food items \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  Future<int> insertFoodItem(FoodItem item) async {
    final db = await database;
    return db.insert('food_items', item.toMap());
  }

  Future<List<FoodItem>> getFoodItemsForMeal(int mealId) async {
    final db = await database;
    final rows = await db.query('food_items', where: 'meal_id = ?', whereArgs: [mealId]);
    return rows.map(FoodItem.fromMap).toList();
  }

  Future<void> deleteFoodItem(int id) async {
    final db = await database;
    await db.delete('food_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalCaloriesForDate(DateTime date) async {
    final meals = await getMealsForDate(date);
    return meals.fold<double>(0.0, (sum, m) => sum + m.totalCalories);
  }

  // \u2500\u2500 Sleep \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  Future<SleepEntry?> getSleepForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('sleep_entries', where: 'date LIKE ?', whereArgs: ['\$dateStr%']);
    if (rows.isEmpty) return null;
    return SleepEntry.fromMap(rows.first);
  }

  Future<List<SleepEntry>> getRecentSleep(int days) async {
    final db = await database;
    final rows = await db.query('sleep_entries', orderBy: 'date DESC', limit: days);
    return rows.map(SleepEntry.fromMap).toList();
  }

  Future<void> upsertSleep(SleepEntry entry) async {
    final db = await database;
    await db.insert('sleep_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSleep(int id) async {
    final db = await database;
    await db.delete('sleep_entries', where: 'id = ?', whereArgs: [id]);
  }

  // \u2500\u2500 Weight \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  Future<List<WeightEntry>> getRecentWeight(int days) async {
    final db = await database;
    final rows = await db.query('weight_entries', orderBy: 'date DESC', limit: days);
    return rows.map(WeightEntry.fromMap).toList();
  }

  Future<WeightEntry?> getWeightForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('weight_entries', where: 'date LIKE ?', whereArgs: ['\$dateStr%']);
    if (rows.isEmpty) return null;
    return WeightEntry.fromMap(rows.first);
  }

  Future<int> insertWeight(WeightEntry entry) async {
    final db = await database;
    return db.insert('weight_entries', entry.toMap());
  }

  Future<void> deleteWeight(int id) async {
    final db = await database;
    await db.delete('weight_entries', where: 'id = ?', whereArgs: [id]);
  }

  // \u2500\u2500 Training \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  Future<List<TrainingEntry>> getTrainingForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('training_entries', where: 'date LIKE ?', whereArgs: ['\$dateStr%'], orderBy: 'date ASC');
    return rows.map(TrainingEntry.fromMap).toList();
  }

  Future<List<TrainingEntry>> getRecentTraining(int days) async {
    final db = await database;
    final rows = await db.query('training_entries', orderBy: 'date DESC', limit: days);
    return rows.map(TrainingEntry.fromMap).toList();
  }

  Future<int> insertTraining(TrainingEntry entry) async {
    final db = await database;
    return db.insert('training_entries', entry.toMap());
  }

  Future<void> deleteTraining(int id) async {
    final db = await database;
    await db.delete('training_entries', where: 'id = ?', whereArgs: [id]);
  }

  // \u2500\u2500 Meal plans \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  Future<int> insertMealPlan(MealPlan plan) async {
    final db = await database;
    return db.insert('meal_plans', plan.toMap());
  }

  Future<void> updateMealPlan(MealPlan plan) async {
    final db = await database;
    await db.update('meal_plans', plan.toMap(),
        where: 'id = ?', whereArgs: [plan.id]);
  }

  Future<void> deleteMealPlan(int id) async {
    final db = await database;
    await db.delete('meal_plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<MealPlan?> getMealPlanForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('meal_plans',
        where: 'date LIKE ?', whereArgs: ['\$dateStr%'], limit: 1);
    if (rows.isEmpty) return null;
    final plan = MealPlan.fromMap(rows.first);
    final items = await getPlanItems(plan.id!);
    return plan.copyWith(items: items);
  }

  Future<List<MealPlan>> getAllMealPlans() async {
    final db = await database;
    final rows = await db.query('meal_plans', orderBy: 'date DESC');
    final plans = <MealPlan>[];
    for (final row in rows) {
      final plan = MealPlan.fromMap(row);
      final items = await getPlanItems(plan.id!);
      plans.add(plan.copyWith(items: items));
    }
    return plans;
  }

  // \u2500\u2500 Plan items \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  Future<void> insertPlanItems(List<PlanItem> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('plan_items', item.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updatePlanItemOptimal(int itemId, double optimalGrams) async {
    final db = await database;
    await db.update('plan_items', {'optimal_grams': optimalGrams},
        where: 'id = ?', whereArgs: [itemId]);
  }

  Future<List<PlanItem>> getPlanItems(int planId) async {
    final db = await database;
    final rows = await db
        .query('plan_items', where: 'plan_id = ?', whereArgs: [planId]);
    return rows.map(PlanItem.fromMap).toList();
  }
}
"""

dart_content = dart_content.replace('SERBIAN_FOODS', serbian_foods)
out_path = 'd:/OneDrive/ClaudeCodeProjects/KcalTracker/lib/database/database_helper.dart'
open(out_path, 'w', encoding='utf-8').write(dart_content)
print(f'Written {len(dart_content)} chars, {len(food_rows)} Serbian foods')
