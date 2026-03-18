import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/meals_provider.dart';

class AddMealScreen extends ConsumerStatefulWidget {
  const AddMealScreen({super.key});

  @override
  ConsumerState<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends ConsumerState<AddMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  TimeOfDay _time = TimeOfDay.now();

  static const _presets = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Combine the selected date with the chosen time.
    final date = ref.read(selectedDateProvider);
    final dateTime = DateTime(
        date.year, date.month, date.day, _time.hour, _time.minute);

    await ref.read(mealsProvider.notifier).addMeal(_nameCtrl.text.trim(), dateTime);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('New Meal')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick-pick chips
                Wrap(
                  spacing: 8,
                  children: _presets
                      .map((p) => ActionChip(
                            label: Text(p),
                            onPressed: () => setState(() => _nameCtrl.text = p),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Meal name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 16),

                // Time picker
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text('Time: ${_time.format(context)}'),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Create Meal'),
                ),
              ],
            ),
          ),
        ),
      );
}
