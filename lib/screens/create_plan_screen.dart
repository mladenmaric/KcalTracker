import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/food_definition.dart';
import '../models/plan_item.dart';
import '../providers/food_database_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/meals_provider.dart';

// ── In-memory state for building the plan before saving ──────────────────────

class _FoodEntry {
  final FoodDefinition food;
  double minGrams;
  double maxGrams;
  _FoodEntry(this.food, this.minGrams, this.maxGrams);
}

class _MealEntry {
  String name;
  final List<_FoodEntry> foods;
  _MealEntry(this.name) : foods = [];
}

// ─────────────────────────────────────────────────────────────────────────────

class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  final _meals = <_MealEntry>[
    _MealEntry('Breakfast'),
    _MealEntry('Lunch'),
    _MealEntry('Dinner'),
  ];

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(selectedDateProvider);

    return Scaffold(
      appBar: AppBar(
        title:
            Text('Plan — ${DateFormat('EEE, MMM d').format(date)}'),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Nutritional preview ─────────────────────────────────────
          _NutritionPreview(meals: _meals),

          // ── Meal list ───────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              children: [
                for (int mi = 0; mi < _meals.length; mi++)
                  _MealCard(
                    meal: _meals[mi],
                    onAddFood: () => _pickFood(_meals[mi]),
                    onRemoveFood: (fi) =>
                        setState(() => _meals[mi].foods.removeAt(fi)),
                    onEditGrams: (fi) =>
                        _editGrams(_meals[mi], fi),
                    onRemoveMeal: _meals.length > 1
                        ? () => setState(() => _meals.removeAt(mi))
                        : null,
                    onRenameMeal: () => _renameMeal(mi),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addMeal,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Meal'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _canSave =>
      _meals.any((m) => m.foods.isNotEmpty);

  // ── Add meal ────────────────────────────────────────────────────────

  void _addMeal() {
    final presets = ['Snack', 'Pre-workout', 'Post-workout', 'Supper'];
    showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Meal name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                children: presets
                    .map((p) => ActionChip(
                          label: Text(p),
                          onPressed: () => Navigator.pop(ctx, p),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                    hintText: 'Custom name…',
                    border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Add')),
          ],
        );
      },
    ).then((name) {
      if (name != null && name.isNotEmpty) {
        setState(() => _meals.add(_MealEntry(name)));
      }
    });
  }

  // ── Rename meal ──────────────────────────────────────────────────────

  void _renameMeal(int index) {
    final ctrl = TextEditingController(text: _meals[index].name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename meal'),
        content: TextField(
          controller: ctrl,
          decoration:
              const InputDecoration(border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(
                    () => _meals[index].name = ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Pick food from database ──────────────────────────────────────────

  Future<void> _pickFood(_MealEntry meal) async {
    final food = await showModalBottomSheet<FoodDefinition>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _FoodPickerSheet(),
    );
    if (food == null || !mounted) return;

    // Ask for min/max grams
    final range = await _showGramsDialog(food.name, 100, 200);
    if (range == null) return;
    setState(() => meal.foods
        .add(_FoodEntry(food, range.$1, range.$2)));
  }

  // ── Edit existing food's gram range ─────────────────────────────────

  Future<void> _editGrams(_MealEntry meal, int fi) async {
    final entry = meal.foods[fi];
    final range = await _showGramsDialog(
        entry.food.name, entry.minGrams, entry.maxGrams);
    if (range == null) return;
    setState(() {
      meal.foods[fi].minGrams = range.$1;
      meal.foods[fi].maxGrams = range.$2;
    });
  }

  Future<(double, double)?> _showGramsDialog(
      String foodName, double initMin, double initMax) async {
    final minCtrl =
        TextEditingController(text: initMin.toStringAsFixed(0));
    final maxCtrl =
        TextEditingController(text: initMax.toStringAsFixed(0));

    return showDialog<(double, double)?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(foodName),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Min (g)',
                    border: OutlineInputBorder()),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('–'),
            ),
            Expanded(
              child: TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Max (g)',
                    border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final mn = double.tryParse(minCtrl.text) ?? 0;
              final mx = double.tryParse(maxCtrl.text) ?? 0;
              if (mn > 0 && mx >= mn) {
                Navigator.pop(ctx, (mn, mx));
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Save plan ────────────────────────────────────────────────────────

  Future<void> _save() async {
    final date = ref.read(selectedDateProvider);
    final planName =
        DateFormat('MMM d, yyyy').format(date);

    final items = <PlanItem>[];
    for (final meal in _meals) {
      for (final entry in meal.foods) {
        items.add(PlanItem(
          planId: 0, // will be set by provider
          mealName: meal.name,
          foodDefinitionId: entry.food.id!,
          foodName: entry.food.name,
          minGrams: entry.minGrams,
          maxGrams: entry.maxGrams,
          caloriesPer100g: entry.food.caloriesPer100g,
          proteinPer100g: entry.food.proteinPer100g,
          carbsPer100g: entry.food.carbsPer100g,
          fatPer100g: entry.food.fatPer100g,
        ));
      }
    }

    await ref
        .read(currentPlanProvider.notifier)
        .createPlan(planName, items);

    if (mounted) context.pop();
  }
}

// ── Nutrition preview card ────────────────────────────────────────────────────

class _NutritionPreview extends StatelessWidget {
  final List<_MealEntry> meals;
  const _NutritionPreview({required this.meals});

  @override
  Widget build(BuildContext context) {
    double minKcal = 0, maxKcal = 0;
    double minP = 0, maxP = 0;

    for (final meal in meals) {
      for (final e in meal.foods) {
        minKcal += e.food.caloriesForGrams(e.minGrams);
        maxKcal += e.food.caloriesForGrams(e.maxGrams);
        minP += e.food.proteinForGrams(e.minGrams);
        maxP += e.food.proteinForGrams(e.maxGrams);
      }
    }

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _PreviewStat('Calories',
              '${minKcal.toStringAsFixed(0)}–${maxKcal.toStringAsFixed(0)}',
              'kcal'),
          _PreviewStat('Protein',
              '${minP.toStringAsFixed(0)}–${maxP.toStringAsFixed(0)}',
              'g'),
          _PreviewStat(
              'Foods',
              meals.fold<int>(0, (s, m) => s + m.foods.length).toString(),
              'items'),
        ],
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _PreviewStat(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('$value $unit',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
        ],
      );
}

// ── Meal card ─────────────────────────────────────────────────────────────────

class _MealCard extends StatelessWidget {
  final _MealEntry meal;
  final VoidCallback onAddFood;
  final void Function(int) onRemoveFood;
  final void Function(int) onEditGrams;
  final VoidCallback? onRemoveMeal;
  final VoidCallback onRenameMeal;

  const _MealCard({
    required this.meal,
    required this.onAddFood,
    required this.onRemoveFood,
    required this.onEditGrams,
    required this.onRemoveMeal,
    required this.onRenameMeal,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(meal.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onRenameMeal),
                if (onRemoveMeal != null)
                  IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onRemoveMeal),
              ],
            ),
          ),
          if (meal.foods.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('No foods yet.',
                  style: TextStyle(color: Colors.grey)),
            ),
          for (int fi = 0; fi < meal.foods.length; fi++)
            ListTile(
              dense: true,
              title: Text(meal.foods[fi].food.name),
              subtitle: Text(
                '${meal.foods[fi].minGrams.toStringAsFixed(0)}–'
                '${meal.foods[fi].maxGrams.toStringAsFixed(0)} g  '
                '· ${meal.foods[fi].food.caloriesForGrams(meal.foods[fi].minGrams).toStringAsFixed(0)}'
                '–${meal.foods[fi].food.caloriesForGrams(meal.foods[fi].maxGrams).toStringAsFixed(0)} kcal',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => onEditGrams(fi)),
                  IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          size: 18),
                      onPressed: () => onRemoveFood(fi)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextButton.icon(
              onPressed: onAddFood,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add food'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Food picker bottom sheet ──────────────────────────────────────────────────

class _FoodPickerSheet extends ConsumerStatefulWidget {
  const _FoodPickerSheet();

  @override
  ConsumerState<_FoodPickerSheet> createState() =>
      _FoodPickerSheetState();
}

class _FoodPickerSheetState extends ConsumerState<_FoodPickerSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(foodDefinitionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (v) =>
                  ref.read(foodSearchQueryProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Search foods…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _ctrl.clear();
                          ref
                              .read(foodSearchQueryProvider.notifier)
                              .state = '';
                        })
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: foodsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (foods) => ListView.builder(
                controller: scrollCtrl,
                itemCount: foods.length,
                itemBuilder: (ctx2, i) {
                  final food = foods[i];
                  return ListTile(
                    title: Text(food.name),
                    subtitle: Text(
                      '${food.caloriesPer100g.toStringAsFixed(0)} kcal  '
                      '| P ${food.proteinPer100g}g  '
                      '| C ${food.carbsPer100g}g  '
                      '| F ${food.fatPer100g}g  (per 100g)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () => Navigator.pop(context, food),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
