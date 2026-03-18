import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';

void main() {
  runApp(
    // ProviderScope is required by Riverpod — it holds all provider state.
    const ProviderScope(
      child: KcalTrackerApp(),
    ),
  );
}

class KcalTrackerApp extends StatelessWidget {
  const KcalTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kcal Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      // GoRouter handles all navigation.
      routerConfig: appRouter,
    );
  }
}
