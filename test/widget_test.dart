import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:best_ball_madness/main.dart';
import 'package:best_ball_madness/theme/theme.dart';

void main() {
  testWidgets('Design system gallery smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame, wrapped in ProviderScope as required by Riverpod.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const DesignSystemGallery(),
        ),
      ),
    );

    // Verify that our design system header renders.
    expect(find.text('BBM DESIGN SYSTEM'), findsOneWidget);

    // Verify that core typography headers render.
    expect(find.text('TYPOGRAPHY'), findsOneWidget);
    expect(find.text('CARDS & INTERACTIVITY'), findsOneWidget);
    expect(find.text('BUTTONS'), findsOneWidget);

    // Verify presence of interactive components like BbmButton
    expect(find.text('Primary Button'), findsOneWidget);
  });
}
