import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Best Ball Madness',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const DesignSystemGallery(),
    );
  }
}

class DesignSystemGallery extends StatelessWidget {
  const DesignSystemGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('BBM DESIGN SYSTEM'),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _buildSectionHeader(theme, 'Typography'),
          Text('Outfit Display Large', style: theme.textTheme.displayLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('Outfit Display Medium', style: theme.textTheme.displayMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Outfit Display Small', style: theme.textTheme.displaySmall),
          const SizedBox(height: AppSpacing.xs),
          Text('Outfit Headline Medium', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Outfit Headline Small', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text('Outfit Title Large', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('Outfit Body Large (Primary)', style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('Outfit Body Medium (Secondary)', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text('Outfit Label Large', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader(theme, 'Cards & Interactivity'),
          BbmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Standard Card Title', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This is a standard card container with custom borders and background colors aligned to our dark mode design system.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          BbmCard(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Interactive Card Tapped!')),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Interactive Card', style: theme.textTheme.titleLarge),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Hovering or tapping on this card triggers a premium scaling animation and changes the border colors.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader(theme, 'Buttons'),
          Row(
            children: [
              Expanded(
                child: BbmButton(
                  text: 'Primary Button',
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: BbmButton(
                  text: 'Loading...',
                  isLoading: true,
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: BbmButton.outlined(
                  text: 'Outlined Button',
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: BbmButton.text(
                  text: 'Text Link Button',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader(theme, 'Pill Badges'),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              BbmBadge.tournamentStatus('SCHEDULED'),
              BbmBadge.tournamentStatus('LIVE'),
              BbmBadge.tournamentStatus('SUSPENDED'),
              BbmBadge.tournamentStatus('COMPLETED'),
              BbmBadge.teamStatus('ACTIVE'),
              BbmBadge.teamStatus('CUT'),
              BbmBadge.teamStatus('DQ'),
              BbmBadge.golferStatus('MC'),
              BbmBadge.golferStatus('WD'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader(theme, 'Loading Skeletons'),
          const BbmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BbmSkeleton(width: 150, height: 20),
                SizedBox(height: AppSpacing.sm),
                BbmSkeleton(width: double.infinity, height: 14),
                SizedBox(height: AppSpacing.xs),
                BbmSkeleton(width: 250, height: 14),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader(theme, 'Horizontal-Scrollable Table'),
          BbmTable(
            minWidth: 500,
            columnWidths: const [2.5, 1.2, 1.2, 1.2, 1.5],
            headers: [
              Text('Golfer', style: theme.textTheme.labelLarge),
              Text('Price', style: theme.textTheme.labelLarge, textAlign: TextAlign.right),
              Text('Rank', style: theme.textTheme.labelLarge, textAlign: TextAlign.right),
              Text('Avg', style: theme.textTheme.labelLarge, textAlign: TextAlign.right),
              Text('Status', style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
            ],
            rows: [
              _buildSampleTableRow('Scottie Scheffler', '\$30.50', '1', '68.2', 'ACTIVE', theme),
              _buildSampleTableRow('Rory McIlroy', '\$29.00', '2', '69.1', 'ACTIVE', theme),
              _buildSampleTableRow('Jon Rahm', '\$28.20', '5', '69.5', 'WD', theme),
              _buildSampleTableRow('Tiger Woods', '\$20.00', '100', '72.4', 'MC', theme),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader(theme, 'Empty State Screen'),
          BbmCard(
            padding: EdgeInsets.zero,
            child: BbmEmptyState(
              title: 'No Active Tournaments',
              message: 'Check back soon! The next PGA Tour event will lock on Thursday morning.',
              action: BbmButton(
                text: 'Refresh Schedule',
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const Divider(color: AppColors.primary, thickness: 1),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildSampleTableRow(
    String name,
    String price,
    String rank,
    String avg,
    String status,
    ThemeData theme,
  ) {
    return BbmTableRow(
      columnWidths: const [2.5, 1.2, 1.2, 1.2, 1.5],
      cells: [
        Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        Text(price, style: theme.textTheme.bodyMedium, textAlign: TextAlign.right),
        Text(rank, style: theme.textTheme.bodyMedium, textAlign: TextAlign.right),
        Text(avg, style: theme.textTheme.bodyMedium, textAlign: TextAlign.right),
        Center(child: BbmBadge.golferStatus(status)),
      ],
    );
  }
}
