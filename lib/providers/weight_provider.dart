import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weight_entry.dart';
import 'auth_provider.dart';
import 'meals_provider.dart';

final weightProvider =
    AsyncNotifierProvider<WeightNotifier, List<WeightEntry>>(WeightNotifier.new);

class WeightNotifier extends AsyncNotifier<List<WeightEntry>> {
  SupabaseClient get _db  => Supabase.instance.client;
  String         get _uid => _db.auth.currentUser!.id;

  @override
  Future<List<WeightEntry>> build() async {
    ref.watch(currentUserProvider);
    ref.watch(selectedDateProvider);
    final data = await _db
        .from('weight_entries')
        .select()
        .eq('user_id', _uid)
        .order('date', ascending: false)
        .limit(60);

    return data.map((e) => WeightEntry.fromMap(e)).toList();
  }

  Future<void> add(double kg) async {
    final date = ref.read(selectedDateProvider);
    await _db.from('weight_entries').insert({
      'user_id':   _uid,
      'weight_kg': kg,
      'date':      date.toIso8601String(),
    });
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await _db.from('weight_entries').delete().eq('id', id);
    ref.invalidateSelf();
  }
}
