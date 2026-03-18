import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/weight_entry.dart';
import 'meals_provider.dart';

final weightProvider =
    AsyncNotifierProvider<WeightNotifier, List<WeightEntry>>(WeightNotifier.new);

class WeightNotifier extends AsyncNotifier<List<WeightEntry>> {
  @override
  Future<List<WeightEntry>> build() async {
    ref.watch(selectedDateProvider); // re-fetch when date changes
    return DatabaseHelper.instance.getRecentWeight(60);
  }

  Future<void> add(double kg) async {
    final date = ref.read(selectedDateProvider);
    await DatabaseHelper.instance.insertWeight(
      WeightEntry(date: date, weightKg: kg),
    );
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await DatabaseHelper.instance.deleteWeight(id);
    ref.invalidateSelf();
  }
}
