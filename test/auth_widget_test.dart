import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:best_ball_madness/screens/auth/auth_screen.dart';
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
      overrides: [
        supabaseClientProvider.overrideWithValue(fakeSupabaseClient),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const AuthScreen(),
      ),
    );
  }

  testWidgets('AuthScreen renders login by default', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    // Verify Title and Subtitle
    expect(find.text('BEST BALL MADNESS'), findsOneWidget);
    expect(find.text('Sign in to manage your golf rosters'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);

    // Verify Fields
    expect(find.widgetWithText(TextFormField, 'Email Address'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);

    // Verify buttons
    expect(find.widgetWithText(ElevatedButton, 'Log In'), findsOneWidget);
    expect(find.text("Don't have an account? "), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Sign Up'), findsOneWidget);
  });

  testWidgets('AuthScreen toggles to signup mode and back', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    // Tap the switch button to toggle to Sign Up mode
    final signUpToggle = find.widgetWithText(TextButton, 'Sign Up');
    expect(signUpToggle, findsOneWidget);
    await tester.tap(signUpToggle);
    await tester.pumpAndSettle();

    // Verify Sign Up mode title and descriptions
    expect(find.text('Create your account to start drafting'), findsOneWidget);
    expect(find.text('REGISTER'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign Up'), findsOneWidget);
    expect(find.text('Already have an account? '), findsOneWidget);

    // Tap switch button back to Log In mode
    final logInToggle = find.widgetWithText(TextButton, 'Log In');
    expect(logInToggle, findsOneWidget);
    await tester.tap(logInToggle);
    await tester.pumpAndSettle();

    // Verify back to Log In mode
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log In'), findsOneWidget);
  });

  testWidgets('AuthScreen shows validation errors for empty fields', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    // Tap Log In button without filling details
    final loginBtn = find.widgetWithText(ElevatedButton, 'Log In');
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    // Verify validation error texts
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('AuthScreen validates email format and password length', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    final emailField = find.widgetWithText(TextFormField, 'Email Address');
    final passwordField = find.widgetWithText(TextFormField, 'Password');
    final loginBtn = find.widgetWithText(ElevatedButton, 'Log In');

    // 1. Enter invalid email and short password
    await tester.enterText(emailField, 'invalid-email');
    await tester.enterText(passwordField, '12345');
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    // Verify validation errors
    expect(find.text('Please enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);

    // 2. Fix email and password to be valid
    await tester.enterText(emailField, 'test@example.com');
    await tester.enterText(passwordField, 'password123');
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    // Verify errors disappear
    expect(find.text('Please enter a valid email address'), findsNothing);
    expect(find.text('Password must be at least 6 characters'), findsNothing);
  });

  testWidgets('AuthScreen submits login credentials successfully', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    final emailField = find.widgetWithText(TextFormField, 'Email Address');
    final passwordField = find.widgetWithText(TextFormField, 'Password');
    final loginBtn = find.widgetWithText(ElevatedButton, 'Log In');

    // Enter valid credentials
    await tester.enterText(emailField, 'user@domain.com');
    await tester.enterText(passwordField, 'pass12345');
    await tester.tap(loginBtn);
    await tester.pump(); // Start request

    // Verify button goes into loading state (checking for circular progress indicator)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle(); // Resolve request

    // Verify fake auth client methods were called
    expect(fakeSupabaseClient.fakeAuth.loginCalled, isTrue);
    expect(fakeSupabaseClient.fakeAuth.lastEmail, 'user@domain.com');
    expect(fakeSupabaseClient.fakeAuth.lastPassword, 'pass12345');
  });

  testWidgets('AuthScreen submits signup credentials successfully', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    // Toggle to Sign Up mode
    await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
    await tester.pumpAndSettle();

    final emailField = find.widgetWithText(TextFormField, 'Email Address');
    final passwordField = find.widgetWithText(TextFormField, 'Password');
    final signUpBtn = find.widgetWithText(ElevatedButton, 'Sign Up');

    // Enter valid credentials
    await tester.enterText(emailField, 'newuser@domain.com');
    await tester.enterText(passwordField, 'newpass123');
    await tester.tap(signUpBtn);
    await tester.pump(); // Start request

    // Verify loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle(); // Resolve request

    // Verify fake auth client methods were called
    expect(fakeSupabaseClient.fakeAuth.signUpCalled, isTrue);
    expect(fakeSupabaseClient.fakeAuth.lastEmail, 'newuser@domain.com');
    expect(fakeSupabaseClient.fakeAuth.lastPassword, 'newpass123');
  });
}
