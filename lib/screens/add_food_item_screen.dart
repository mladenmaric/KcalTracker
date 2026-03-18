import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/database_helper.dart';
import '../models/food_definition.dart';
import '../models/food_item.dart';
import '../providers/food_api_provider.dart';
import '../providers/food_database_provider.dart';
import '../providers/meals_provider.dart';

class AddFoodItemScreen extends ConsumerStatefulWidget {
  final int mealId;
  const AddFoodItemScreen({super.key, required this.mealId});

  @override
  ConsumerState<AddFoodItemScreen> createState() => _AddFoodItemScreenState();
}

class _AddFoodItemScreenState extends ConsumerState<AddFoodItemScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _localSearchCtrl = TextEditingController();
  final _onlineSearchCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController();

  FoodDefinition? _selected;
  Timer? _debounce;

  // Tracks the latest submitted online query (so we only search on pause).
  String _submittedOnlineQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    // Clear selection when switching tabs.
    _tabs.addListener(() => setState(() => _selected = null));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _localSearchCtrl.dispose();
    _onlineSearchCtrl.dispose();
    _gramsCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Local search ─────────────────────────────────────────────────────────

  void _onLocalSearchChanged(String value) {
    ref.read(foodSearchQueryProvider.notifier).state = value;
    setState(() => _selected = null);
  }

  // ── Online search (debounced 600ms) ──────────────────────────────────────

  void _onOnlineSearchChanged(String value) {
    _debounce?.cancel();
    setState(() => _selected = null);
    if (value.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _submittedOnlineQuery = value.trim());
    });
  }

  // ── Grams & preview ──────────────────────────────────────────────────────

  double get _grams => double.tryParse(_gramsCtrl.text) ?? 0;

  ({double kcal, double protein, double carbs, double fat}) get _preview {
    final def = _selected;
    if (def == null || _grams <= 0) {
      return (kcal: 0, protein: 0, carbs: 0, fat: 0);
    }
    return (
      kcal: def.caloriesForGrams(_grams),
      protein: def.proteinForGrams(_grams),
      carbs: def.carbsForGrams(_grams),
      fat: def.fatForGrams(_grams),
    );
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    var def = _selected;
    if (def == null || _grams <= 0) return;

    // If this food came from the online search it has no id yet —
    // save it to the local database first so it's available next time.
    if (def.id == null) {
      final newId = await DatabaseHelper.instance.insertFoodDefinition(def);
      def = def.copyWith(id: newId);
      // Refresh the local food list so the new entry shows up there too.
      ref.invalidate(foodDefinitionsProvider);
    }

    final p = _preview;
    await ref.read(mealsProvider.notifier).addFoodItem(
          FoodItem(
            mealId: widget.mealId,
            foodDefinitionId: def.id!,
            name: def.name,
            grams: _grams,
            calories: p.kcal,
            protein: p.protein,
            carbs: p.carbs,
            fat: p.fat,
          ),
        );
    if (mounted) context.pop();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Food'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.storage), text: 'My Database'),
            Tab(icon: Icon(Icons.cloud_outlined), text: 'Online Search'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _LocalTab(
                  searchCtrl: _localSearchCtrl,
                  selected: _selected,
                  onSearchChanged: _onLocalSearchChanged,
                  onFoodSelected: (f) => setState(() {
                    _selected = f;
                    _gramsCtrl.clear();
                  }),
                ),
                _OnlineTab(
                  searchCtrl: _onlineSearchCtrl,
                  query: _submittedOnlineQuery,
                  selected: _selected,
                  onSearchChanged: _onOnlineSearchChanged,
                  onFoodSelected: (f) => setState(() {
                    _selected = f;
                    _gramsCtrl.clear();
                  }),
                ),
              ],
            ),
          ),

          // Grams panel — shown once a food is selected in either tab.
          if (_selected != null)
            _GramsPanel(
              food: _selected!,
              gramsCtrl: _gramsCtrl,
              preview: _preview,
              isOnlineFood: _selected!.id == null,
              onChanged: () => setState(() {}),
              onSave: _save,
            ),
        ],
      ),
    );
  }
}

// ── Local tab ────────────────────────────────────────────────────────────────

class _LocalTab extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final FoodDefinition? selected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<FoodDefinition> onFoodSelected;

  const _LocalTab({
    required this.searchCtrl,
    required this.selected,
    required this.onSearchChanged,
    required this.onFoodSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(foodDefinitionsProvider);

    return Column(
      children: [
        _SearchBar(
          ctrl: searchCtrl,
          hint: 'Search your foods…',
          onChanged: onSearchChanged,
        ),
        Expanded(
          child: foodsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (foods) => foods.isEmpty
                ? const Center(
                    child: Text('No foods found.\nTry the Online Search tab.',
                        textAlign: TextAlign.center))
                : _FoodList(
                    foods: foods,
                    selected: selected,
                    onFoodSelected: onFoodSelected,
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Online tab ───────────────────────────────────────────────────────────────

class _OnlineTab extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final String query;
  final FoodDefinition? selected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<FoodDefinition> onFoodSelected;

  const _OnlineTab({
    required this.searchCtrl,
    required this.query,
    required this.selected,
    required this.onSearchChanged,
    required this.onFoodSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _SearchBar(
          ctrl: searchCtrl,
          hint: 'Search Open Food Facts…',
          onChanged: onSearchChanged,
        ),
        Expanded(child: _buildResults(ref)),
      ],
    );
  }

  Widget _buildResults(WidgetRef ref) {
    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Type a food name to search\nOpen Food Facts database',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final resultsAsync = ref.watch(onlineFoodSearchProvider(query));
    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Search failed: $e\n\nCheck your internet connection.',
              textAlign: TextAlign.center),
        ),
      ),
      data: (foods) => foods.isEmpty
          ? const Center(child: Text('No results found. Try a different name.'))
          : _FoodList(
              foods: foods,
              selected: selected,
              onFoodSelected: onFoodSelected,
              showSaveHint: true,
            ),
    );
  }
}

// ── Shared food list ──────────────────────────────────────────────────────────

class _FoodList extends StatelessWidget {
  final List<FoodDefinition> foods;
  final FoodDefinition? selected;
  final ValueChanged<FoodDefinition> onFoodSelected;
  final bool showSaveHint;

  const _FoodList({
    required this.foods,
    required this.selected,
    required this.onFoodSelected,
    this.showSaveHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: foods.length,
      itemBuilder: (context, i) {
        final food = foods[i];
        final isSelected = selected?.name == food.name;
        return ListTile(
          selected: isSelected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          title: Text(food.name),
          subtitle: Text(
            '${food.caloriesPer100g.toStringAsFixed(0)} kcal  '
            '| P ${food.proteinPer100g.toStringAsFixed(1)}g  '
            '| C ${food.carbsPer100g.toStringAsFixed(1)}g  '
            '| F ${food.fatPer100g.toStringAsFixed(1)}g'
            '  (per 100g)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: showSaveHint && food.id == null
              ? Tooltip(
                  message: 'Will be saved to your database',
                  child: Icon(Icons.cloud_download_outlined,
                      size: 18, color: Colors.grey.shade400),
                )
              : null,
          onTap: () => onFoodSelected(food),
        );
      },
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.ctrl,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    ctrl.clear();
                    onChanged('');
                  },
                )
              : null,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

// ── Grams panel ───────────────────────────────────────────────────────────────

class _GramsPanel extends StatelessWidget {
  final FoodDefinition food;
  final TextEditingController gramsCtrl;
  final ({double kcal, double protein, double carbs, double fat}) preview;
  final bool isOnlineFood;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  const _GramsPanel({
    required this.food,
    required this.gramsCtrl,
    required this.preview,
    required this.isOnlineFood,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final hasGrams = (double.tryParse(gramsCtrl.text) ?? 0) > 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(food.name,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (isOnlineFood)
                Chip(
                  label: const Text('Will save to DB'),
                  avatar:
                      const Icon(Icons.cloud_download_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: gramsCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              suffixText: 'g',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onChanged(),
          ),
          if (hasGrams) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroChip(
                    label: 'Calories',
                    value: preview.kcal.toStringAsFixed(0),
                    unit: 'kcal',
                    color: Colors.orange),
                _MacroChip(
                    label: 'Protein',
                    value: preview.protein.toStringAsFixed(1),
                    unit: 'g',
                    color: Colors.blue),
                _MacroChip(
                    label: 'Carbs',
                    value: preview.carbs.toStringAsFixed(1),
                    unit: 'g',
                    color: Colors.amber.shade700),
                _MacroChip(
                    label: 'Fat',
                    value: preview.fat.toStringAsFixed(1),
                    unit: 'g',
                    color: Colors.red),
              ],
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: hasGrams ? onSave : null,
            icon: const Icon(Icons.add),
            label: const Text('Add to Meal'),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MacroChip(
      {required this.label,
      required this.value,
      required this.unit,
      required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('$value $unit',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
        ],
      );
}
