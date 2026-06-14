import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/responsive_layout.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onViewDesignSystem;

  const DashboardScreen({
    super.key,
    required this.onViewDesignSystem,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(userProfileProvider);

    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('BBM DASHBOARD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _isLoggingOut ? null : _logout,
            tooltip: 'Logout',
          )
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Header
              profileAsync.when(
                data: (profile) {
                  if (profile == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WELCOME BACK,',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        profile.teamName.toUpperCase(),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Manage your teams and track live scoring below.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error loading profile: $err'),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Team Info Card
              profileAsync.when(
                data: (profile) {
                  if (profile == null) {
                    return const BbmCard(
                      child: Text('No team profile active. Please complete setup.'),
                    );
                  }
                  return BbmCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield, color: AppColors.primary, size: 24),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Team Details', style: theme.textTheme.titleLarge),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildDetailRow('Team Name', profile.teamName, theme),
                        const Divider(color: AppColors.border, height: AppSpacing.lg),
                        _buildDetailRow('Email Address', profile.email, theme),
                        const Divider(color: AppColors.border, height: AppSpacing.lg),
                        _buildDetailRow(
                          'Created', 
                          '${profile.createdAt.month}/${profile.createdAt.day}/${profile.createdAt.year}', 
                          theme,
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Navigation & Controls Card
              BbmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'DEVELOPER OPTIONS',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    BbmButton.outlined(
                      text: 'View Design System Gallery',
                      icon: Icons.palette_outlined,
                      onPressed: widget.onViewDesignSystem,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    BbmButton.outlined(
                      text: 'Log Out',
                      icon: Icons.exit_to_app,
                      onPressed: _isLoggingOut ? null : _logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}
