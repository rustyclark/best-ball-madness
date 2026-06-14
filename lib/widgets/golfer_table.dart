import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/draft_providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'badge.dart';
import 'table.dart';

enum GolferSortColumn { name, price, rank, average }

class GolferTable extends ConsumerStatefulWidget {
  final List<TournamentGolfer> golfers;
  final bool isLocked;

  const GolferTable({super.key, required this.golfers, required this.isLocked});

  @override
  ConsumerState<GolferTable> createState() => _GolferTableState();
}

class _GolferTableState extends ConsumerState<GolferTable> {
  GolferSortColumn _sortBy = GolferSortColumn.price;
  bool _ascending = false; // default price desc

  List<TournamentGolfer> _getSortedGolfers() {
    final list = List<TournamentGolfer>.from(widget.golfers);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case GolferSortColumn.name:
          cmp = a.profile.name.compareTo(b.profile.name);
          break;
        case GolferSortColumn.price:
          cmp = a.price.compareTo(b.price);
          break;
        case GolferSortColumn.rank:
          final rA = a.profile.worldRank ?? 9999;
          final rB = b.profile.worldRank ?? 9999;
          cmp = rA.compareTo(rB);
          break;
        case GolferSortColumn.average:
          final avA = a.profile.scoringAvg ?? 999.0;
          final avB = b.profile.scoringAvg ?? 999.0;
          cmp = avA.compareTo(avB);
          break;
      }
      return _ascending ? cmp : -cmp;
    });
    return list;
  }

  String _formatTeeTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final hour = localTime.hour > 12
        ? localTime.hour - 12
        : (localTime.hour == 0 ? 12 : localTime.hour);
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = localTime.hour >= 12 ? 'PM' : 'AM';
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final day = days[localTime.weekday - 1];
    return '$day $hour:$minute $period';
  }

  Widget _buildSortableHeader(
    String label,
    GolferSortColumn column,
    ThemeData theme,
  ) {
    final isSorted = _sortBy == column;
    return InkWell(
      onTap: () {
        setState(() {
          if (_sortBy == column) {
            _ascending = !_ascending;
          } else {
            _sortBy = column;
            _ascending = column != GolferSortColumn.price;
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: column == GolferSortColumn.name
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isSorted ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isSorted) ...[
              const SizedBox(width: 2),
              Icon(
                _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedGolfers = ref.watch(draftStateNotifierProvider);
    final sortedGolfers = _getSortedGolfers();

    const columnWidths = [2.5, 1.2, 0.8, 1.0, 1.8, 1.5];

    return BbmTable(
      minWidth: 600.0,
      columnWidths: columnWidths,
      headers: [
        _buildSortableHeader('Golfer', GolferSortColumn.name, theme),
        _buildSortableHeader('Price', GolferSortColumn.price, theme),
        _buildSortableHeader('WR', GolferSortColumn.rank, theme),
        _buildSortableHeader('Avg', GolferSortColumn.average, theme),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Stats',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Text(
            'Action',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
      rows: sortedGolfers.map((golfer) {
        final isSelected = selectedGolfers.any((g) => g.id == golfer.id);

        final String statsText =
            '${golfer.profile.wins ?? 0}W / ${golfer.profile.top10s ?? 0}T10 / ${golfer.profile.cutsMade ?? 0}C';

        return BbmTableRow(
          columnWidths: columnWidths,
          cells: [
            // Golfer Name & Tee Time/Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  golfer.profile.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (golfer.status == 'WD' || golfer.status == 'MC')
                  Text(
                    golfer.status,
                    style: const TextStyle(
                      color: AppColors.scoreBogeyBg,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else if (golfer.teeTime != null)
                  Text(
                    _formatTeeTime(golfer.teeTime!),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            // Price
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '\$${golfer.price.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // WR (World Rank)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                golfer.profile.worldRank != null
                    ? '${golfer.profile.worldRank}'
                    : '-',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            // Avg (Scoring Average)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                golfer.profile.scoringAvg != null
                    ? golfer.profile.scoringAvg!.toStringAsFixed(1)
                    : '-',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            // Stats
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                statsText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            // Action Button
            Center(
              child: widget.isLocked
                  ? (isSelected
                        ? BbmBadge.teamStatus('ACTIVE')
                        : const SizedBox.shrink())
                  : (isSelected
                        ? ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(draftStateNotifierProvider.notifier)
                                  .removeGolfer(golfer);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.scoreBogeyBg,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 4,
                              ),
                              minimumSize: const Size(64, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppSpacing.borderRadiusSm,
                              ),
                            ),
                            child: const Text(
                              'REMOVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              final success = ref
                                  .read(draftStateNotifierProvider.notifier)
                                  .addGolfer(golfer);
                              if (!success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Roster is already full! Remove a golfer first.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 4,
                              ),
                              minimumSize: const Size(64, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppSpacing.borderRadiusSm,
                              ),
                            ),
                            child: const Text(
                              'ADD',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )),
            ),
          ],
        );
      }).toList(),
    );
  }
}
