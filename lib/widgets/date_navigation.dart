import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/meals_provider.dart';

/// A row widget showing [<] [date label] [>] used as the AppBar title
/// on every date-based screen. Arrows shift [selectedDateProvider] by one
/// day; the right arrow is disabled when already on today.
class DateNavigator extends ConsumerWidget {
  const DateNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date == today;

    void shift(int days) {
      final next = date.add(Duration(days: days));
      if (next.isAfter(today)) return;
      ref.read(selectedDateProvider.notifier).state = next;
    }

    final label = isToday ? 'Today' : DateFormat('EEE, MMM d').format(date);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => shift(-1),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right,
            color: isToday
                ? Theme.of(context).disabledColor
                : null,
          ),
          onPressed: isToday ? null : () => shift(1),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
