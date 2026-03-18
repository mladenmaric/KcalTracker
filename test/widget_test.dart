import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcal_tracker/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: KcalTrackerApp()),
    );
    // Just verify the app renders at all.
    expect(find.byType(KcalTrackerApp), findsOneWidget);
  });
}
