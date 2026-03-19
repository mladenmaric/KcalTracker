import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food_definition.dart';
import '../providers/food_database_provider.dart';

// FoodDatabaseScreen — browse, add, edit, and delete food definitions.
class FoodDatabaseScreen extends ConsumerStatefulWidget {
  const FoodDatabaseScreen({super.key});

  @override
  ConsumerState<FoodDatabaseScreen> createState() => _FoodDatabaseScreenState();
}

class _FoodDatabaseScreenState extends ConsumerState<FoodDatabaseScreen> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(foodDefinitionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add food',
            onPressed: () => _showEditDialog(context, ref, null),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search foods…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: foodsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (foods) {
                final filtered = _searchQuery.isEmpty
                    ? foods
                    : foods
                        .where((f) => f.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No foods found.'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final food = filtered[i];
                    return ListTile(
                      title: Text(food.name),
                      subtitle: Text(
                        '${food.caloriesPer100g.toStringAsFixed(0)} kcal  '
                        '| P ${food.proteinPer100g}g  '
                        '| C ${food.carbsPer100g}g  '
                        '| F ${food.fatPer100g}g  (per 100g)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showEditDialog(context, ref, food),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(context, ref, food),
                          ),
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
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, FoodDefinition food) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete food?'),
        content: Text(
            '"${food.name}" will be removed from the database.\nExisting logged meals are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () {
              ref.read(foodDefinitionsProvider.notifier).delete(food.id!);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, FoodDefinition? existing) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _FoodEditDialog(existing: existing),
    );
  }
}

class _FoodEditDialog extends ConsumerStatefulWidget {
  final FoodDefinition? existing;
  const _FoodEditDialog({this.existing});

  @override
  ConsumerState<_FoodEditDialog> createState() => _FoodEditDialogState();
}

class _FoodEditDialogState extends ConsumerState<_FoodEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _kcal = TextEditingController(
        text: e != null ? e.caloriesPer100g.toString() : '');
    _protein = TextEditingController(
        text: e != null ? e.proteinPer100g.toString() : '');
    _carbs = TextEditingController(
        text: e != null ? e.carbsPer100g.toString() : '');
    _fat =
        TextEditingController(text: e != null ? e.fatPer100g.toString() : '');
  }

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  String _normalizeDecimal(String v) => v.replaceAll(',', '.');

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final def = FoodDefinition(
      id: widget.existing?.id,
      name: _name.text.trim(),
      caloriesPer100g: double.parse(_normalizeDecimal(_kcal.text)),
      proteinPer100g: double.parse(_normalizeDecimal(_protein.text)),
      carbsPer100g: double.parse(_normalizeDecimal(_carbs.text)),
      fatPer100g: double.parse(_normalizeDecimal(_fat.text)),
    );
    final notifier = ref.read(foodDefinitionsProvider.notifier);
    if (widget.existing == null) {
      await notifier.add(def);
    } else {
      await notifier.save(def);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Food' : 'Add Food'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_name, 'Name', isText: true),
              _field(_kcal, 'Calories (per 100g)', suffix: 'kcal'),
              _field(_protein, 'Protein (per 100g)', suffix: 'g'),
              _field(_carbs, 'Carbs (per 100g)', suffix: 'g'),
              _field(_fat, 'Fat (per 100g)', suffix: 'g'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {String? suffix, bool isText = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isText
            ? TextInputType.text
            : const TextInputType.numberWithOptions(decimal: true),
        textCapitalization:
            isText ? TextCapitalization.sentences : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (!isText && double.tryParse(_normalizeDecimal(v)) == null) return 'Enter a number';
          return null;
        },
      ),
    );
  }
}
