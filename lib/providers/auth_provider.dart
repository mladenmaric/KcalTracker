import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_profile.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/trainer/trainer_screen.dart';
import '../screens/trainer/user_detail_screen.dart';
import '../screens/add_food_item_screen.dart';
import '../screens/add_meal_screen.dart';
import '../screens/create_plan_screen.dart';
import '../screens/food_database_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/main_shell.dart';
import '../screens/plan_history_screen.dart';
import '../screens/planner_screen.dart';
import '../screens/sleep_screen.dart';
import '../screens/training_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/weekly_stats_screen.dart';
import '../screens/weight_screen.dart';
import '../services/notification_service.dart';

// ── Supabase client ──────────────────────────────────────────────────────────

final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

// ── Auth state stream ────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

// ── Current signed-in user (null = logged out) ───────────────────────────────

final currentUserProvider = Provider<User?>((ref) {
  // Re-evaluate whenever auth state changes.
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

// ── Current user's profile (role, display name) ──────────────────────────────

final profileProvider = FutureProvider<AppProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final data = await ref
      .watch(supabaseClientProvider)
      .from('profiles')
      .select()
      .eq('id', user.id)
      .single();

  return AppProfile.fromMap(data);
});

// ── Current user's assigned trainer (if any) ─────────────────────────────────

final myTrainerProvider = FutureProvider<AppProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final db   = ref.watch(supabaseClientProvider);
  final data = await db
      .from('trainer_assignments')
      .select('trainer:profiles!trainer_id(id, display_name, role)')
      .eq('user_id', user.id)
      .maybeSingle();

  if (data == null) return null;
  return AppProfile.fromMap(data['trainer'] as Map<String, dynamic>);
});

// ── Realtime: notify athlete when trainer posts a new comment ─────────────────

final commentNotificationProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  final channel = Supabase.instance.client
      .channel('athlete-comment-notifications')
      .onPostgresChanges(
        event:    PostgresChangeEvent.insert,
        schema:   'public',
        table:    'meal_comments',
        callback: (payload) {
          final trainerId = payload.newRecord['trainer_id'] as String?;
          // Don't notify the trainer about their own comment.
          if (trainerId == user.id) return;
          NotificationService.show(
            title: 'Trainer feedback',
            body:  'Your trainer left a comment on one of your meals.',
          );
        },
      )
      .subscribe();

  ref.onDispose(() => channel.unsubscribe());
});

// ── Router notifier — tells GoRouter to re-evaluate redirect on auth change ──

class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

final _authRouterNotifier = _AuthRouterNotifier();

// ── GoRouter (Riverpod provider so it can access auth state) ─────────────────

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _authRouterNotifier,

    // Redirect unauthenticated users to login; bounce logged-in users away
    // from auth pages.
    redirect: (context, state) {
      final isLoggedIn  = Supabase.instance.client.auth.currentUser != null;
      final isOnAuth    = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isOnAuth) return '/auth/login';
      if (isLoggedIn  &&  isOnAuth) return '/';
      return null;
    },

    routes: [
      // ── Auth routes (no shell / bottom nav) ─────────────────────────────
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (ctx, st) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        builder: (ctx, st) => const RegisterScreen(),
      ),

      // ── Shell: the 5 bottom-nav tabs ─────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (ctx, st) => const HomeScreen(),
          ),
          GoRoute(
            path: '/sleep',
            name: 'sleep',
            builder: (ctx, st) => const SleepScreen(),
          ),
          GoRoute(
            path: '/weight',
            name: 'weight',
            builder: (ctx, st) => const WeightScreen(),
          ),
          GoRoute(
            path: '/training',
            name: 'training',
            builder: (ctx, st) => const TrainingScreen(),
          ),
          GoRoute(
            path: '/planner',
            name: 'planner',
            builder: (ctx, st) => const PlannerScreen(),
          ),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ───────────────────────────────
      GoRoute(
        path: '/add-meal',
        name: 'add-meal',
        builder: (ctx, st) => const AddMealScreen(),
      ),
      GoRoute(
        path: '/add-food-item/:mealId',
        name: 'add-food-item',
        builder: (_, state) {
          final mealId = int.parse(state.pathParameters['mealId']!);
          return AddFoodItemScreen(mealId: mealId);
        },
      ),
      GoRoute(
        path: '/food-database',
        name: 'food-database',
        builder: (ctx, st) => const FoodDatabaseScreen(),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (ctx, st) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/goals',
        name: 'goals',
        builder: (ctx, st) => const GoalsScreen(),
      ),
      GoRoute(
        path: '/create-plan',
        name: 'create-plan',
        builder: (ctx, st) => const CreatePlanScreen(),
      ),
      GoRoute(
        path: '/plan-history',
        name: 'plan-history',
        builder: (ctx, st) => const PlanHistoryScreen(),
      ),
      GoRoute(
        path: '/weekly-stats',
        name: 'weekly-stats',
        builder: (ctx, st) => const WeeklyStatsScreen(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (ctx, st) => const AdminScreen(),
      ),
      GoRoute(
        path: '/trainer',
        name: 'trainer',
        builder: (ctx, st) => const TrainerScreen(),
      ),
      GoRoute(
        path: '/trainer/user/:userId',
        name: 'user-detail',
        builder: (ctx, state) => UserDetailScreen(
          userId:   state.pathParameters['userId']!,
          userName: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (ctx, st) => const ProfileScreen(),
      ),
    ],
  );
});
