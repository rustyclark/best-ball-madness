import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:best_ball_madness/screens/auth/reset_password_screen.dart';
import 'package:best_ball_madness/providers/auth_providers.dart';
import 'package:best_ball_madness/theme/theme.dart';
import 'helpers/fake_supabase.dart';

void main() {
  late FakeSupabaseClient fakeSupabaseClient;

  setUp(() {
    fakeSupabaseClient = FakeSupabaseClient();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [supabaseClientProvider.overrideWithValue(fakeSupabaseClient)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ResetPasswordScreen(),
      ),
    );
  }

  testWidgets('ResetPasswordScreen renders correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());

    expect(find.text('RESET PASSWORD'), findsOneWidget);
    expect(
      find.text('Choose a secure new password for your account'),
      findsOneWidget,
    );
    expect(find.text('ENTER NEW PASSWORD'), findsOneWidget);

    // Verify fields exist
    expect(find.widgetWithText(TextFormField, 'New Password'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      findsOneWidget,
    );

    // Verify buttons exist
    expect(
      find.widgetWithText(ElevatedButton, 'Update Password'),
      findsOneWidget,
    );
    expect(find.text('Cancel & Sign Out'), findsOneWidget);
  });

  testWidgets('ResetPasswordScreen validates empty and mismatched inputs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());

    final updateBtn = find.widgetWithText(ElevatedButton, 'Update Password');

    // 1. Submit empty form
    await tester.tap(updateBtn);
    await tester.pumpAndSettle();

    expect(find.text('Please enter a password'), findsOneWidget);

    // 2. Submit short password
    final newPasswordFields = find.widgetWithText(
      TextFormField,
      'New Password',
    );
    final confirmPasswordFields = find.widgetWithText(
      TextFormField,
      'Confirm Password',
    );

    await tester.enterText(newPasswordFields, '12345');
    await tester.tap(updateBtn);
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);

    // 3. Submit mismatched confirm password
    await tester.enterText(newPasswordFields, 'password123');
    await tester.enterText(confirmPasswordFields, 'different123');
    await tester.tap(updateBtn);
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('ResetPasswordScreen updates password successfully', (
    WidgetTester tester,
  ) async {
    // Override the isPasswordRecoveryProvider to true initially
    final container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(fakeSupabaseClient)],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ResetPasswordScreen(),
        ),
      ),
    );

    // Set the recovery state to true
    container.read(isPasswordRecoveryProvider.notifier).setRecovery(true);
    expect(container.read(isPasswordRecoveryProvider), isTrue);

    final newPasswordFields = find.widgetWithText(
      TextFormField,
      'New Password',
    );
    final confirmPasswordFields = find.widgetWithText(
      TextFormField,
      'Confirm Password',
    );
    final updateBtn = find.widgetWithText(ElevatedButton, 'Update Password');

    // Fill in valid details
    await tester.enterText(newPasswordFields, 'securepassword');
    await tester.enterText(confirmPasswordFields, 'securepassword');
    await tester.tap(updateBtn);
    await tester.pumpAndSettle();

    // Verify updateUser called with correct password
    expect(fakeSupabaseClient.fakeAuth.updateUserCalled, isTrue);
    expect(
      fakeSupabaseClient.fakeAuth.lastUserAttributes?.password,
      'securepassword',
    );

    // Verify snackbar is displayed
    expect(find.text('Password updated successfully!'), findsOneWidget);

    // Verify recovery state is set to false
    expect(container.read(isPasswordRecoveryProvider), isFalse);
  });

  testWidgets('ResetPasswordScreen Cancel & Sign Out signs out successfully', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(fakeSupabaseClient)],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ResetPasswordScreen(),
        ),
      ),
    );

    container.read(isPasswordRecoveryProvider.notifier).setRecovery(true);
    expect(container.read(isPasswordRecoveryProvider), isTrue);

    final cancelBtn = find.text('Cancel & Sign Out');
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();

    // Verify signOut called and recovery flow is closed
    expect(fakeSupabaseClient.fakeAuth.signOutCalled, isTrue);
    expect(container.read(isPasswordRecoveryProvider), isFalse);
  });
}
