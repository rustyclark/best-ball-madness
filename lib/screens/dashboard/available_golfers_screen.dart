import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/draft_providers.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/golfer_table.dart';
import '../../widgets/responsive_layout.dart';

class AvailableGolfersScreen extends ConsumerWidget {
  final List<TournamentGolfer> golfers;
  final bool isLocked;

  const AvailableGolfersScreen({
    super.key,
    required this.golfers,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedGolfers = ref.watch(draftStateNotifierProvider);

    // Calculate spend and budget
    final double totalSpend = selectedGolfers.fold<double>(
      0,
      (sum, g) => sum + g.price,
    );
    final double remainingBudget = 100.0 - totalSpend;
    final bool isOverBudget = remainingBudget < 0;
    final bool isRosterComplete = selectedGolfers.length == 4;

    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('AVAILABLE GOLFERS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: !isLocked
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ROSTER: ${selectedGolfers.length} / 4 SLOTS',
                          style: TextStyle(
                            color: isRosterComplete
                                ? AppColors.accent
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'BUDGET: \$${remainingBudget.toStringAsFixed(2)} LEFT',
                          style: TextStyle(
                            color: isOverBudget
                                ? AppColors.scoreBogeyBg
                                : AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.borderRadiusMd,
                        ),
                      ),
                      child: const Text(
                        'DONE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'DRAFT TEAM GOLFERS',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Browse, search, and sort golfers. Click a row to view their scoring averages and career stats.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: GolferTable(golfers: golfers, isLocked: isLocked),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
