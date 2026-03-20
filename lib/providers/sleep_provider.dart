import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sleep_entry.dart';
import 'auth_provider.dart';
import 'meals_provider.dart';

final sleepProvider =
    AsyncNotifierProvider<SleepNotifier, SleepEntry?>(SleepNotifier.new);

class SleepNotifier extends AsyncNotifier<SleepEntry?> {
  SupabaseClient get _db  => Supabase.instance.client;
  String         get _uid => _db.auth.currentUser!.id;

  @override
  Future<SleepEntry?> build() async {
    ref.watch(currentUserProvider);
    final date    = ref.watch(selectedDateProvider);
    final dateStr = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final data = await _db
        .from('sleep_entries')
        .select()
        .eq('user_id', _uid)
        .eq('date', dateStr)
        .maybeSingle();

    return data == null ? null : SleepEntry.fromMap(data);
  }

  Future<void> save(String? sleepTime, String? wakeTime) async {
    final date    = ref.read(selectedDateProvider);
    final dateStr = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    await _db.from('sleep_entries').upsert(
      {
        'user_id':    _uid,
        'date':       dateStr,
        'sleep_time': sleepTime,
        'wake_time':  wakeTime,
      },
      onConflict: 'user_id,date',
    );
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await _db.from('sleep_entries').delete().eq('id', id);
    ref.invalidateSelf();
  }
}

final recentSleepProvider = FutureProvider<List<SleepEntry>>((ref) async {
  ref.watch(currentUserProvider);
  final db  = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;

  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final data   = await db
      .from('sleep_entries')
      .select()
      .eq('user_id', uid)
      .gte('date', cutoff.toIso8601String().substring(0, 10))
      .order('date', ascending: false);

  return data.map((e) => SleepEntry.fromMap(e)).toList();
});
