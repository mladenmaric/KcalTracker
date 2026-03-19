import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/weight_entry.dart';
import '../providers/meals_provider.dart';
import '../providers/weight_provider.dart';

class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date        = ref.watch(selectedDateProvider);
    final weightAsync = ref.watch(weightProvider);
    final now         = DateTime.now();
    final today       = DateTime(now.year, now.month, now.day);
    final isToday     = date == today;

    return Scaffold(
      appBar: AppBar(
        // Title is just "Weight" — the list always shows recent history,
        // not filtered by date. The date picker sets which date new entries
        // will be logged to.
        title: const Text('Weight'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            // Tooltip shows current log date so user always knows what date
            // a new entry will be saved to.
            tooltip: isToday
                ? 'Log date: today'
                : 'Log date: ${DateFormat('MMM d').format(date)} — tap to change',
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
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (entries) => Column(
          children: [
            // ── Latest weight card ──────────────────────────────────────
            _LatestWeightCard(latest: entries.isEmpty ? null : entries.first),

            // Show a banner when logging for a past date
            if (!isToday)
              MaterialBanner(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                content: Text(
                  'Logging for ${DateFormat('EEE, MMM d').format(date)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                actions: [
                  TextButton(
                    onPressed: () => ref
                        .read(selectedDateProvider.notifier)
                        .state = today,
                    child: const Text('Back to today'),
                  ),
                ],
              ),

            const Divider(height: 1),

            // ── History list ────────────────────────────────────────────
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Text(
                          'No weight logged yet.\nTap + to add.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final entry = entries[i];
                        final prev  = i < entries.length - 1
                            ? entries[i + 1]
                            : null;
                        final delta = prev != null
                            ? entry.weightKg - prev.weightKg
                            : null;
                        return Dismissible(
                          key: Key('weight-${entry.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(Icons.delete,
                                color: Colors.white),
                          ),
                          onDismissed: (_) {
                            ref
                                .read(weightProvider.notifier)
                                .delete(entry.id!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Entry deleted')),
                            );
                          },
                          child: ListTile(
                            leading: const Icon(
                                Icons.monitor_weight_outlined),
                            title: Text(
                                '${entry.weightKg.toStringAsFixed(1)} kg'),
                            subtitle: Text(DateFormat('EEE, MMM d')
                                .format(entry.date)),
                            trailing: delta != null
                                ? _DeltaChip(delta: delta)
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref, date, isToday),
        icon: const Icon(Icons.add),
        label: const Text('Log Weight'),
      ),
    );
  }

  void _showAddDialog(
      BuildContext context, WidgetRef ref, DateTime date, bool isToday) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Weight'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isToday)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Logging for ${DateFormat('EEE, MMM d').format(date)}',
                  style: TextStyle(
                      color: Colors.orange.shade700, fontSize: 12),
                ),
              ),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight',
                suffixText: 'kg',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final kg =
                  double.tryParse(ctrl.text.replaceAll(',', '.'));
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
}

class _LatestWeightCard extends StatelessWidget {
  final WeightEntry? latest;
  const _LatestWeightCard({required this.latest});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.monitor_weight_outlined,
                size: 36, color: Colors.teal),
            const SizedBox(width: 12),
            latest == null
                ? Text('No data yet',
                    style: Theme.of(context).textTheme.headlineSmall)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${latest!.weightKg.toStringAsFixed(1)} kg',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal),
                      ),
                      Text(
                        'Last logged ${DateFormat('MMM d').format(latest!.date)}',
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
    final isUp  = delta > 0;
    final color = isUp ? Colors.red : Colors.green;
    final icon  = isUp ? Icons.arrow_upward : Icons.arrow_downward;
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
