import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/meals_provider.dart';
import '../providers/sleep_provider.dart';

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final sleepAsync = ref.watch(sleepProvider);
    final recentAsync = ref.watch(recentSleepProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Sleep — ${DateFormat('MMM d').format(date)}'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Today's sleep card ──────────────────────────────────────
          sleepAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (entry) => _SleepCard(entry: entry),
          ),
          const SizedBox(height: 24),

          // ── Recent history ───────────────────────────────────────────
          Text('Recent', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          recentAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (entries) {
              if (entries.isEmpty) {
                return const Text('No sleep data logged yet.',
                    style: TextStyle(color: Colors.grey));
              }
              return Column(
                children: entries.map((e) => _SleepHistoryTile(entry: e)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SleepCard extends ConsumerStatefulWidget {
  final dynamic entry;
  const _SleepCard({required this.entry});

  @override
  ConsumerState<_SleepCard> createState() => _SleepCardState();
}

class _SleepCardState extends ConsumerState<_SleepCard> {
  String? _sleepTime;
  String? _wakeTime;

  @override
  void initState() {
    super.initState();
    _sleepTime = widget.entry?.sleepTime;
    _wakeTime = widget.entry?.wakeTime;
  }

  String _formatTime(String? t) => t ?? '—';

  Future<void> _pickTime(bool isSleep) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      helpText: isSleep ? 'Bedtime' : 'Wake-up time',
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isSleep) {
        _sleepTime = formatted;
      } else {
        _wakeTime = formatted;
      }
    });
    await ref.read(sleepProvider.notifier).save(_sleepTime, _wakeTime);
  }

  @override
  Widget build(BuildContext context) {
    // Recalculate duration from current state.
    int? duration;
    final s = _parseTime(_sleepTime);
    final w = _parseTime(_wakeTime);
    if (s != null && w != null) {
      final diff = w - s;
      duration = diff >= 0 ? diff : diff + 1440;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Tonight's Sleep",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    icon: Icons.bedtime_outlined,
                    label: 'Bedtime',
                    value: _formatTime(_sleepTime),
                    color: Colors.indigo,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeButton(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Wake up',
                    value: _formatTime(_wakeTime),
                    color: Colors.orange,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            if (duration != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timelapse, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: ${duration ~/ 60}h ${duration % 60}m',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  int? _parseTime(String? t) {
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}

class _TimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _TimeButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}

class _SleepHistoryTile extends StatelessWidget {
  final dynamic entry;
  const _SleepHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: const Icon(Icons.bedtime_outlined, color: Colors.indigo),
        title: Text(DateFormat('EEE, MMM d').format(entry.date)),
        subtitle: Text(
            '${entry.sleepTime ?? '—'}  →  ${entry.wakeTime ?? '—'}'),
        trailing: Text(
          entry.durationLabel,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
        ),
      );
}
