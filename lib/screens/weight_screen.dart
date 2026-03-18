import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/meals_provider.dart';
import '../providers/weight_provider.dart';

class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final weightAsync = ref.watch(weightProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Weight — ${DateFormat('MMM d').format(date)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
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
      body: weightAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) => Column(
          children: [
            // ── Latest weight card ────────────────────────────────────
            _LatestWeightCard(latest: entries.isEmpty ? null : entries.first),
            const Divider(height: 1),

            // ── History list ──────────────────────────────────────────
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Text('No weight logged yet.\nTap + to add.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final entry = entries[i];
                        final prev = i < entries.length - 1 ? entries[i + 1] : null;
                        final delta = prev != null
                            ? entry.weightKg - prev.weightKg
                            : null;
                        return ListTile(
                          leading: const Icon(Icons.monitor_weight_outlined),
                          title: Text(
                              '${entry.weightKg.toStringAsFixed(1)} kg'),
                          subtitle: Text(
                              DateFormat('EEE, MMM d').format(entry.date)),
                          trailing: delta != null
                              ? _DeltaChip(delta: delta)
                              : null,
                          onLongPress: () =>
                              _confirmDelete(context, ref, entry.id!),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Weight'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Weight',
            suffixText: 'kg',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final kg = double.tryParse(ctrl.text);
              if (kg != null && kg > 0) {
                ref.read(weightProvider.notifier).add(kg);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(weightProvider.notifier).delete(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _LatestWeightCard extends StatelessWidget {
  final dynamic latest;
  const _LatestWeightCard({required this.latest});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.monitor_weight_outlined, size: 36, color: Colors.teal),
            const SizedBox(width: 12),
            latest == null
                ? Text('No data yet',
                    style: Theme.of(context).textTheme.headlineSmall)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${latest.weightKg.toStringAsFixed(1)} kg',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      Text(
                        'Last logged ${DateFormat('MMM d').format(latest.date)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
          ],
        ),
      );
}

class _DeltaChip extends StatelessWidget {
  final double delta;
  const _DeltaChip({required this.delta});

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0;
    final color = isUp ? Colors.red : Colors.green;
    final icon = isUp ? Icons.arrow_upward : Icons.arrow_downward;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        Text(
          '${delta.abs().toStringAsFixed(1)} kg',
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
