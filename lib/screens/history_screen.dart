import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../providers/meals_provider.dart';

// HistoryScreen — tap a past date to jump to it on the home screen.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show the last 30 days (most recent first).
    final today = DateTime.now();
    final days = List.generate(
      30,
      (i) => DateTime(today.year, today.month, today.day - i),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ListView.builder(
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          return _DayTile(day: day);
        },
      ),
    );
  }
}

// Each tile loads the calorie total for that day asynchronously.
class _DayTile extends ConsumerWidget {
  final DateTime day;
  const _DayTile({required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(_dayCaloriesProvider(day));

    return ListTile(
      title: Text(DateFormat('EEEE, MMM d').format(day)),
      subtitle: totalAsync.when(
        data: (kcal) => Text('${kcal.toStringAsFixed(0)} kcal'),
        loading: () => const Text('Loading…'),
        error: (_, _) => const Text('—'),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        ref.read(selectedDateProvider.notifier).state = day;
        context.pop(); // go back to home, which now shows this day
      },
    );
  }
}

// Fetches total calories for a specific date directly from the DB,
// independently of the global selectedDateProvider.
final _dayCaloriesProvider =
    FutureProvider.family<double, DateTime>((ref, date) {
  return DatabaseHelper.instance.getTotalCaloriesForDate(date);
});
