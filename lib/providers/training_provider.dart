import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/training_entry.dart';
import 'meals_provider.dart';

final trainingProvider =
    AsyncNotifierProvider<TrainingNotifier, List<TrainingEntry>>(TrainingNotifier.new);

class TrainingNotifier extends AsyncNotifier<List<TrainingEntry>> {
  @override
  Future<List<TrainingEntry>> build() async {
    final date = ref.watch(selectedDateProvider);
    return DatabaseHelper.instance.getTrainingForDate(date);
  }

  Future<void> add(String type, int durationMinutes, DateTime dateTime, {String? notes}) async {
    await DatabaseHelper.instance.insertTraining(
      TrainingEntry(date: dateTime, type: type, durationMinutes: durationMinutes, notes: notes),
    );
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await DatabaseHelper.instance.deleteTraining(id);
    ref.invalidateSelf();
  }
}
