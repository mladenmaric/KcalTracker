import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/training_entry.dart';
import '../providers/meals_provider.dart';
import '../providers/training_provider.dart';
import '../widgets/date_navigation.dart';

class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date          = ref.watch(selectedDateProvider);
    final trainingAsync = ref.watch(trainingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const DateNavigator(),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Jump to date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                ref.read(selectedDateProvider.notifier).state = picked;
              }
            },
          ),
        ],
      ),
      body: trainingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'No training logged.\nTap + to add.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              return Dismissible(
                key: Key('training-${entry.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  ref.read(trainingProvider.notifier).delete(entry.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('${entry.type} session deleted')),
                  );
                },
                child: _TrainingTile(entry: entry),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (ctx) => const _AddTrainingDialog(),
        ),
        icon: const Icon(Icons.fitness_center),
        label: const Text('Log Workout'),
      ),
    );
  }
}

// Pure display tile — delete is handled via Dismissible in the parent.
class _TrainingTile extends StatelessWidget {
  final TrainingEntry entry;
  const _TrainingTile({required this.entry});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: Text(_emoji(entry.type),
                style: const TextStyle(fontSize: 20)),
          ),
          title: Text(entry.type,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: entry.notes != null && entry.notes!.isNotEmpty
              ? Text(entry.notes!)
              : null,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(entry.durationLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(DateFormat('HH:mm').format(entry.date),
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );

  String _emoji(String type) => switch (type) {
        'Gym'      => '🏋️',
        'Tennis'   => '🎾',
        'Running'  => '🏃',
        'Cycling'  => '🚴',
        'Swimming' => '🏊',
        'Walking'  => '🚶',
        'Yoga'     => '🧘',
        _          => '💪',
      };
}

class _AddTrainingDialog extends ConsumerStatefulWidget {
  const _AddTrainingDialog();

  @override
  ConsumerState<_AddTrainingDialog> createState() =>
      _AddTrainingDialogState();
}

class _AddTrainingDialogState extends ConsumerState<_AddTrainingDialog> {
  String   _type = TrainingEntry.presets.first;
  final    _durationCtrl = TextEditingController();
  final    _notesCtrl    = TextEditingController();
  TimeOfDay _time        = TimeOfDay.now();

  @override
  void dispose() {
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Log Workout'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: TrainingEntry.presets.map((p) {
                  final selected = _type == p;
                  return ChoiceChip(
                    label: Text(p),
                    selected: selected,
                    onSelected: (_) => setState(() => _type = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _durationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  suffixText: 'min',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time),
                label: Text('Time: ${_time.format(context)}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final mins = int.tryParse(_durationCtrl.text);
              if (mins != null && mins > 0) {
                final date = ref.read(selectedDateProvider);
                final dateTime = DateTime(date.year, date.month,
                    date.day, _time.hour, _time.minute);
                ref.read(trainingProvider.notifier).add(
                      _type,
                      mins,
                      dateTime,
                      notes: _notesCtrl.text.trim().isEmpty
                          ? null
                          : _notesCtrl.text.trim(),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
}
