import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/draft_providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../utils/score_utils.dart';
import '../screens/dashboard/available_golfers_screen.dart';
import 'badge.dart';
import 'card.dart';
import 'golfer_avatar.dart';

class DraftPanel extends ConsumerStatefulWidget {
  final bool isLocked;
  final VoidCallback? onSaveSuccess;

  const DraftPanel({super.key, required this.isLocked, this.onSaveSuccess});

  @override
  ConsumerState<DraftPanel> createState() => _DraftPanelState();
}

class _DraftPanelState extends ConsumerState<DraftPanel> {
  String? _saveError;

  Future<void> _handleRemove(TournamentGolfer golfer) async {
    setState(() {
      _saveError = null;
    });

    try {
      await ref.read(draftStateNotifierProvider.notifier).removeGolfer(golfer);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedGolfers = ref.watch(draftStateNotifierProvider);
    final userTeam = ref.watch(userTeamProvider).value;
    final isRosterSaved = userTeam != null && userTeam.golferIds.isNotEmpty;

    final double totalSpend = double.parse(
      selectedGolfers
          .fold<double>(0, (sum, g) => sum + g.price)
          .toStringAsFixed(2),
    );
    final double remainingBudget = 100.0 - totalSpend;
    final bool isOverBudget = totalSpend > 100.0;
    final bool isRosterComplete = selectedGolfers.length == 4;
    final bool hasWdGolfer = selectedGolfers.any((g) => g.status == 'WD');

    return BbmCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Text(
                  'YOUR ROSTER',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.0,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'REMAINING BUDGET: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${remainingBudget.toStringAsFixed(2)}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isOverBudget
                            ? AppColors.scoreBogeyBg
                            : AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: AppColors.border, height: AppSpacing.md),

            // 4 Roster Slots
            ...List.generate(4, (index) {
              if (index < selectedGolfers.length) {
                final golfer = selectedGolfers[index];
                final isGolferLocked =
                    widget.isLocked ||
                    (golfer.teeTime != null &&
                        DateTime.now().toUtc().isAfter(
                          golfer.teeTime!.subtract(const Duration(minutes: 15)),
                        ));

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppSpacing.borderRadiusMd,
                    border: Border.all(
                      color: golfer.status == 'WD'
                          ? AppColors.scoreBogeyBg
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      GolferAvatar(profile: golfer.profile, size: 60),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    golfer.profile.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (golfer.status == 'WD') ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  BbmBadge.golferStatus('WD'),
                                ],
                              ],
                            ),
                            Text(
                              'Price: \$${golfer.price.toStringAsFixed(2)} | Rank: ${golfer.profile.worldRank ?? "-"}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (golfer.teeTime != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  isGolferLocked
                                      ? '🔒 Locked (Teed off)'
                                      : 'Tee Time: ${formatTeeTime(golfer.teeTime!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isGolferLocked
                                        ? AppColors.scoreBogeyBg
                                        : AppColors.primary,
                                    fontWeight: isGolferLocked
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!isGolferLocked)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              label: const Text(
                                'EDIT',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                              onPressed: () {
                                final golfers =
                                    ref.read(golferListProvider).value ?? [];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AvailableGolfersScreen(
                                          golfers: golfers,
                                          isLocked: widget.isLocked,
                                          replacingGolfer: golfer,
                                        ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.scoreBogeyBg,
                                size: 20,
                              ),
                              onPressed: () => _handleRemove(golfer),
                              tooltip: 'Remove',
                            ),
                          ],
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Icon(
                            Icons.lock_outline,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                );
              } else {
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: isRosterSaved ? AppSpacing.xs : AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.5),
                    borderRadius: AppSpacing.borderRadiusMd,
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Empty Slot',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (!widget.isLocked) ...[
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(
                            Icons.add,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          label: const Text(
                            'ADD',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                          onPressed: () {
                            final golfers =
                                ref.read(golferListProvider).value ?? [];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AvailableGolfersScreen(
                                  golfers: golfers,
                                  isLocked: widget.isLocked,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }
            }),

            const SizedBox(height: AppSpacing.sm),

            // Alerts
            if (isOverBudget) ...[
              _buildAlert(
                theme,
                'Budget limit of \$100 exceeded! Remove a golfer.',
                AppColors.scoreBogeyBg,
                Icons.error_outline,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (!isRosterComplete) ...[
              _buildAlert(
                theme,
                'Roster incomplete! Draft exactly 4 golfers.',
                AppColors.statusLiveText,
                Icons.warning_amber_rounded,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (hasWdGolfer && !widget.isLocked) ...[
              _buildAlert(
                theme,
                'A selected golfer has withdrawn (WD)! Please replace them.',
                Colors.amber,
                Icons.warning_amber_rounded,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (_saveError != null) ...[
              _buildAlert(
                theme,
                _saveError!,
                AppColors.scoreBogeyBg,
                Icons.error,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],

            const SizedBox(height: AppSpacing.sm),

            // Save / Lock Status Button
            if (widget.isLocked)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.5),
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'ROSTER LOCKED',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else if (isOverBudget || !isRosterComplete || hasWdGolfer)
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.statusLiveBg.withValues(alpha: 0.3),
                  borderRadius: AppSpacing.borderRadiusMd,
                  border: Border.all(
                    color: AppColors.statusLiveText.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.statusLiveText,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'Changes saved. Roster is currently invalid!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusLiveText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: AppSpacing.borderRadiusMd,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'Roster changes are saved automatically',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlert(
    ThemeData theme,
    String message,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 1),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
