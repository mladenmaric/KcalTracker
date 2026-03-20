import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (path: '/',          icon: Icons.restaurant_menu,         label: 'Nutrition'),
    (path: '/sleep',     icon: Icons.bedtime_outlined,        label: 'Sleep'),
    (path: '/weight',    icon: Icons.monitor_weight_outlined, label: 'Weight'),
    (path: '/training',  icon: Icons.fitness_center,          label: 'Training'),
    (path: '/planner',   icon: Icons.auto_fix_high,           label: 'Planner'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = _tabs.length - 1; i >= 0; i--) {
      if (location.startsWith(_tabs[i].path) &&
          (_tabs[i].path == '/' ? location == '/' : true)) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activates the Supabase Realtime subscription for trainer comment notifications.
    ref.watch(commentNotificationProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}
