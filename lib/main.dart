import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/auth_providers.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/missing_env_screen.dart';
import 'screens/auth/setup_team_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'theme/colors.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  final isConfigured = supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  if (isConfigured) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  } else {
    debugPrint(
      '⚠️ WARNING: Supabase is not configured. SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY environment variables are missing.',
    );
  }

  runApp(ProviderScope(child: MyApp(isConfigured: isConfigured)));
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class MyApp extends ConsumerWidget {
  final bool isConfigured;

  const MyApp({super.key, this.isConfigured = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Best Ball Madness',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      home: isConfigured
          ? const NavigationSwitcher()
          : const MissingEnvScreen(),
    );
  }
}

class NavigationSwitcher extends ConsumerWidget {
  const NavigationSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(authSessionProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          return const AuthScreen();
        }

        final profileAsync = ref.watch(userProfileProvider);

        return profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const SetupTeamScreen();
            }
            return const DashboardScreen();
          },
          loading: () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (err, stack) => Scaffold(
            body: Center(
              child: Text(
                'Error loading profile: $err',
                style: const TextStyle(color: AppColors.scoreBogeyBg),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text(
            'Error checking authentication: $err',
            style: const TextStyle(color: AppColors.scoreBogeyBg),
          ),
        ),
      ),
    );
  }
}
