import 'package:go_router/go_router.dart';

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
import '../screens/weekly_stats_screen.dart';
import '../screens/weight_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ── Shell: the 5 bottom-nav tabs ────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/sleep',
          name: 'sleep',
          builder: (context, state) => const SleepScreen(),
        ),
        GoRoute(
          path: '/weight',
          name: 'weight',
          builder: (context, state) => const WeightScreen(),
        ),
        GoRoute(
          path: '/training',
          name: 'training',
          builder: (context, state) => const TrainingScreen(),
        ),
        GoRoute(
          path: '/planner',
          name: 'planner',
          builder: (context, state) => const PlannerScreen(),
        ),
      ],
    ),

    // ── Full-screen routes (no bottom nav) ───────────────────────────────
    GoRoute(
      path: '/add-meal',
      name: 'add-meal',
      builder: (context, state) => const AddMealScreen(),
    ),
    GoRoute(
      path: '/add-food-item/:mealId',
      name: 'add-food-item',
      builder: (context, state) {
        final mealId = int.parse(state.pathParameters['mealId']!);
        return AddFoodItemScreen(mealId: mealId);
      },
    ),
    GoRoute(
      path: '/food-database',
      name: 'food-database',
      builder: (context, state) => const FoodDatabaseScreen(),
    ),
    GoRoute(
      path: '/history',
      name: 'history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/goals',
      name: 'goals',
      builder: (context, state) => const GoalsScreen(),
    ),
    GoRoute(
      path: '/create-plan',
      name: 'create-plan',
      builder: (context, state) => const CreatePlanScreen(),
    ),
    GoRoute(
      path: '/plan-history',
      name: 'plan-history',
      builder: (context, state) => const PlanHistoryScreen(),
    ),
    GoRoute(
      path: '/weekly-stats',
      name: 'weekly-stats',
      builder: (context, state) => const WeeklyStatsScreen(),
    ),
  ],
);
