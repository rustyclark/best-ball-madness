import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/auth_providers.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/setup_team_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'theme/colors.dart';
import 'theme/spacing.dart';
import 'theme/theme.dart';
import 'widgets/badge.dart';
import 'widgets/button.dart';
import 'widgets/card.dart';
import 'widgets/empty_state.dart';
import 'widgets/responsive_layout.dart';
import 'widgets/skeleton.dart';
import 'widgets/table.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Best Ball Madness',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const NavigationSwitcher(),
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

