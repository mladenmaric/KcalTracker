import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_profile.dart';

// ── Model: user profile + their assigned trainer (if any) ───────────────────

class UserWithTrainer {
  final AppProfile user;
  final AppProfile? trainer;

  const UserWithTrainer({required this.user, this.trainer});
}

// ── All users + their trainer assignments (admin only) ───────────────────────

final allUsersProvider = FutureProvider<List<UserWithTrainer>>((ref) async {
  final db = Supabase.instance.client;

  // Fetch all profiles and all assignments in parallel.
  final results = await Future.wait([
    db.from('profiles').select().order('display_name'),
    db.from('trainer_assignments').select(),
  ]);

  final profiles    = (results[0] as List).map((p) => AppProfile.fromMap(p)).toList();
  final assignments = results[1] as List;

  // Build a map: user_id → trainer_id
  final trainerMap = <String, String>{
    for (final a in assignments) a['user_id'] as String: a['trainer_id'] as String,
  };
  // Profile lookup map
  final profileMap = {for (final p in profiles) p.id: p};

  return profiles.map((user) {
    final trainerId = trainerMap[user.id];
    return UserWithTrainer(
      user:    user,
      trainer: trainerId != null ? profileMap[trainerId] : null,
    );
  }).toList();
});

// ── Admin actions ────────────────────────────────────────────────────────────

class AdminService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<void> setRole(String userId, String role) async {
    await _db.rpc('admin_set_role', params: {
      'target_user_id': userId,
      'new_role':       role,
    });
  }

  Future<void> assignTrainer(String trainerId, String userId) async {
    await _db.rpc('admin_assign_trainer', params: {
      'p_trainer_id': trainerId,
      'p_user_id':    userId,
    });
  }

  Future<void> removeTrainer(String trainerId, String userId) async {
    await _db.rpc('admin_remove_trainer', params: {
      'p_trainer_id': trainerId,
      'p_user_id':    userId,
    });
  }
}

final adminServiceProvider = Provider<AdminService>((_) => AdminService());
