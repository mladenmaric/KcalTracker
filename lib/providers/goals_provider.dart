import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/goals.dart';

const _kKcal    = 'goal_kcal';
const _kProtein = 'goal_protein_pct';
const _kCarbs   = 'goal_carbs_pct';
const _kFat     = 'goal_fat_pct';

final goalsProvider =
    AsyncNotifierProvider<GoalsNotifier, Goals>(GoalsNotifier.new);

class GoalsNotifier extends AsyncNotifier<Goals> {
  @override
  Future<Goals> build() async {
    final prefs = await SharedPreferences.getInstance();
    return Goals(
      dailyKcal:  prefs.getDouble(_kKcal)    ?? 2000,
      proteinPct: prefs.getDouble(_kProtein)  ?? 40,
      carbsPct:   prefs.getDouble(_kCarbs)    ?? 30,
      fatPct:     prefs.getDouble(_kFat)      ?? 30,
    );
  }

  Future<void> save(Goals goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kKcal,    goals.dailyKcal);
    await prefs.setDouble(_kProtein, goals.proteinPct);
    await prefs.setDouble(_kCarbs,   goals.carbsPct);
    await prefs.setDouble(_kFat,     goals.fatPct);
    state = AsyncData(goals);
  }
}
