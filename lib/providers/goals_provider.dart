import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/goals.dart';
import 'auth_provider.dart';

final goalsProvider =
    AsyncNotifierProvider<GoalsNotifier, Goals>(GoalsNotifier.new);

class GoalsNotifier extends AsyncNotifier<Goals> {
  SupabaseClient get _db  => Supabase.instance.client;
  String         get _uid => _db.auth.currentUser!.id;

  @override
  Future<Goals> build() async {
    ref.watch(currentUserProvider);
    final data = await _db
        .from('goals')
        .select()
        .eq('user_id', _uid)
        .maybeSingle();

    if (data == null) return const Goals();

    return Goals(
      dailyKcal:  (data['daily_kcal']  as num).toDouble(),
      proteinPct: (data['protein_pct'] as num).toDouble(),
      carbsPct:   (data['carbs_pct']   as num).toDouble(),
      fatPct:     (data['fat_pct']     as num).toDouble(),
    );
  }

  Future<void> save(Goals goals) async {
    await _db.from('goals').upsert(
      {
        'user_id':     _uid,
        'daily_kcal':  goals.dailyKcal,
        'protein_pct': goals.proteinPct,
        'carbs_pct':   goals.carbsPct,
        'fat_pct':     goals.fatPct,
      },
      onConflict: 'user_id',
    );
    state = AsyncData(goals);
  }
}
