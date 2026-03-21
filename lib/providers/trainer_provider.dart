import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_profile.dart';
import '../models/food_item.dart';
import '../models/meal.dart';
import '../models/meal_comment.dart';
import '../models/sleep_entry.dart';
import '../models/training_entry.dart';
import '../models/weight_entry.dart';

// ── Assigned users for the current trainer ───────────────────────────────────

final assignedUsersProvider = FutureProvider<List<AppProfile>>((ref) async {
  final db  = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;

  final assignments = await db
      .from('trainer_assignments')
      .select('user_id')
      .eq('trainer_id', uid);

  if (assignments.isEmpty) return [];

  final ids = assignments.map((a) => a['user_id'] as String).toList();

  final profiles = await db
      .from('profiles')
      .select()
      .inFilter('id', ids)
      .order('display_name');

  return profiles.map((p) => AppProfile.fromMap(p)).toList();
});

// ── Meals for a specific user + date (trainer read-only view) ────────────────

final trainerUserMealsProvider =
    FutureProvider.family<List<Meal>, ({String userId, DateTime date})>(
  (ref, args) async {
    final db    = Supabase.instance.client;
    final start = DateTime(args.date.year, args.date.month, args.date.day);
    final end   = DateTime(args.date.year, args.date.month, args.date.day, 23, 59, 59, 999);

    final data = await db
        .from('meals')
        .select('*, food_items(*)')
        .eq('user_id', args.userId)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String())
        .order('date', ascending: true);

    return data.map<Meal>((m) {
      final items = (m['food_items'] as List)
          .map((fi) => FoodItem.fromMap(fi as Map<String, dynamic>))
          .toList();
      return Meal.fromMap(m).copyWith(foodItems: items);
    }).toList();
  },
);

// ── Comment for a specific meal ──────────────────────────────────────────────

final trainerCommentProvider =
    FutureProvider.family<MealComment?, int>(
  (ref, mealId) async {
    final db  = Supabase.instance.client;
    final uid = db.auth.currentUser!.id;

    final data = await db
        .from('meal_comments')
        .select()
        .eq('meal_id',    mealId)
        .eq('trainer_id', uid)
        .maybeSingle();

    return data == null ? null : MealComment.fromMap(data);
  },
);

// ── All comments on a meal (athlete read-only view) ──────────────────────────
// FutureProvider so it works reliably on all platforms regardless of Realtime
// publication status. Invalidated by commentNotificationProvider on any change.

final mealCommentsProvider =
    FutureProvider.family<List<MealComment>, int>((ref, mealId) async {
  final data = await Supabase.instance.client
      .from('meal_comments')
      .select()
      .eq('meal_id', mealId)
      .order('created_at');
  return data.map((m) => MealComment.fromMap(m)).toList();
});

// ── Comment service (save / delete) ─────────────────────────────────────────

class CommentService {
  final SupabaseClient _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<void> save({
    required int    mealId,
    required String body,
  }) async {
    await _db.from('meal_comments').upsert(
      {
        'meal_id':    mealId,
        'trainer_id': _uid,
        'body':       body,
      },
      onConflict: 'meal_id,trainer_id',
    );
  }

  Future<void> delete(int commentId) async {
    await _db.from('meal_comments').delete().eq('id', commentId);
  }
}

final commentServiceProvider = Provider<CommentService>((_) => CommentService());

// ── Last 7 weight entries up to a given date (trainer read-only) ─────────────

final trainerUserWeightProvider =
    FutureProvider.family<List<WeightEntry>, ({String userId, DateTime date})>(
  (ref, args) async {
    final end = DateTime(
        args.date.year, args.date.month, args.date.day, 23, 59, 59, 999);
    final data = await Supabase.instance.client
        .from('weight_entries')
        .select()
        .eq('user_id', args.userId)
        .lte('date', end.toIso8601String())
        .order('date', ascending: false)
        .limit(7);
    return data.reversed.map((e) => WeightEntry.fromMap(e)).toList();
  },
);

// ── Sleep entry for a specific user + date (trainer read-only) ───────────────

final trainerUserSleepProvider =
    FutureProvider.family<SleepEntry?, ({String userId, DateTime date})>(
  (ref, args) async {
    final dateStr =
        '${args.date.year.toString().padLeft(4, '0')}-'
        '${args.date.month.toString().padLeft(2, '0')}-'
        '${args.date.day.toString().padLeft(2, '0')}';
    final data = await Supabase.instance.client
        .from('sleep_entries')
        .select()
        .eq('user_id', args.userId)
        .eq('date', dateStr)
        .maybeSingle();
    return data == null ? null : SleepEntry.fromMap(data);
  },
);

// ── Training entries for a specific user + date (trainer read-only) ──────────

final trainerUserTrainingProvider =
    FutureProvider.family<List<TrainingEntry>, ({String userId, DateTime date})>(
  (ref, args) async {
    final start = DateTime(args.date.year, args.date.month, args.date.day);
    final end   = DateTime(args.date.year, args.date.month, args.date.day, 23, 59, 59, 999);
    final data = await Supabase.instance.client
        .from('training_entries')
        .select()
        .eq('user_id', args.userId)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String())
        .order('date', ascending: true);
    return data.map((e) => TrainingEntry.fromMap(e)).toList();
  },
);
