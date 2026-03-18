import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// MainShell wraps the 4 main tabs with a shared bottom navigation bar.
// GoRouter's ShellRoute keeps this widget alive while navigating between tabs.
class MainShell extends StatelessWidget {
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
    // Match the most specific tab first.
    for (var i = _tabs.length - 1; i >= 0; i--) {
      if (location.startsWith(_tabs[i].path) &&
          (_tabs[i].path == '/' ? location == '/' : true)) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
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
