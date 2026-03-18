import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/sleep_entry.dart';
import 'meals_provider.dart';

final sleepProvider =
    AsyncNotifierProvider<SleepNotifier, SleepEntry?>(SleepNotifier.new);

class SleepNotifier extends AsyncNotifier<SleepEntry?> {
  @override
  Future<SleepEntry?> build() async {
    final date = ref.watch(selectedDateProvider);
    return DatabaseHelper.instance.getSleepForDate(date);
  }

  Future<void> save(String? sleepTime, String? wakeTime) async {
    final date = ref.read(selectedDateProvider);
    final existing = state.value;
    final entry = SleepEntry(
      id: existing?.id,
      date: date,
      sleepTime: sleepTime,
      wakeTime: wakeTime,
    );
    await DatabaseHelper.instance.upsertSleep(entry);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await DatabaseHelper.instance.deleteSleep(id);
    ref.invalidateSelf();
  }
}

final recentSleepProvider = FutureProvider<List<SleepEntry>>((ref) {
  return DatabaseHelper.instance.getRecentSleep(30);
});
