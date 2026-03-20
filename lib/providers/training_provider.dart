import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/training_entry.dart';
import 'auth_provider.dart';
import 'meals_provider.dart';

final trainingProvider =
    AsyncNotifierProvider<TrainingNotifier, List<TrainingEntry>>(TrainingNotifier.new);

class TrainingNotifier extends AsyncNotifier<List<TrainingEntry>> {
  SupabaseClient get _db  => Supabase.instance.client;
  String         get _uid => _db.auth.currentUser!.id;

  @override
  Future<List<TrainingEntry>> build() async {
    ref.watch(currentUserProvider);
    final date  = ref.watch(selectedDateProvider);
    final start = DateTime(date.year, date.month, date.day);
    final end   = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final data = await _db
        .from('training_entries')
        .select()
        .eq('user_id', _uid)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String())
        .order('date');

    return data.map((e) => TrainingEntry.fromMap(e)).toList();
  }

  Future<void> add(
    String type,
    int durationMinutes,
    DateTime dateTime, {
    String? notes,
  }) async {
    await _db.from('training_entries').insert({
      'user_id':          _uid,
      'type':             type,
      'duration_minutes': durationMinutes,
      'date':             dateTime.toIso8601String(),
      'notes':            notes,
    });
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await _db.from('training_entries').delete().eq('id', id);
    ref.invalidateSelf();
  }
}
