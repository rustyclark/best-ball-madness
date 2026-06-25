import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/draft_providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'golfer_avatar.dart';

enum GolferSortColumn { name, price, rank, average }

class GolferTable extends ConsumerStatefulWidget {
  final List<TournamentGolfer> golfers;
  final bool isLocked;
  final int? limit;
  final TournamentGolfer? replacingGolfer;

  const GolferTable({
    super.key,
    required this.golfers,
    required this.isLocked,
    this.limit,
    this.replacingGolfer,
  });

  @override
  ConsumerState<GolferTable> createState() => _GolferTableState();
}

class _GolferTableState extends ConsumerState<GolferTable> {
  final TextEditingController _searchController = TextEditingController();
  GolferSortColumn _sortBy = GolferSortColumn.price;
  bool _ascending = false; // default price desc
  String _searchQuery = '';
  final Set<String> _expandedGolferIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TournamentGolfer> _getSortedAndFilteredGolfers() {
    List<TournamentGolfer> list = List<TournamentGolfer>.from(widget.golfers);

    // Apply Search Filter (only if not in preview/limit mode)
    if (widget.limit == null && _searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list
          .where((g) => g.profile.name.toLowerCase().contains(query))
          .toList();
    }

    // Apply Sorting
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
          final avA =
              (a.profile.scoringAvg != null && a.profile.scoringAvg! > 0)
              ? a.profile.scoringAvg!
              : 999.0;
          final avB =
              (b.profile.scoringAvg != null && b.profile.scoringAvg! > 0)
              ? b.profile.scoringAvg!
              : 999.0;
          cmp = avA.compareTo(avB);
          break;
      }
      return _ascending ? cmp : -cmp;
    });

    // Apply Limit (preview mode)
    if (widget.limit != null && list.length > widget.limit!) {
      list = list.sublist(0, widget.limit!);
    }

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

  Widget _buildSearchBar(ThemeData theme) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search golfers by name...',
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                onPressed: () {
                  _searchController.clear();
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.alternateRow,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 0,
          horizontal: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusLg,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusLg,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusLg,
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      style: const TextStyle(color: AppColors.textPrimary),
    );
  }

  Widget _buildSortChips(ThemeData theme) {
    final List<Map<String, dynamic>> sortOptions = [
      {'label': 'Price', 'value': GolferSortColumn.price},
      {'label': 'World Rank', 'value': GolferSortColumn.rank},
      {'label': 'Name', 'value': GolferSortColumn.name},
      {'label': 'Avg Score', 'value': GolferSortColumn.average},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sortOptions.map((opt) {
          final col = opt['value'] as GolferSortColumn;
          final isSelected = _sortBy == col;
          final label = opt['label'] as String;

          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (_sortBy == col) {
                    _ascending = !_ascending;
                  } else {
                    _sortBy = col;
                    _ascending = col != GolferSortColumn.price;
                  }
                });
              },
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.alternateRow,
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.borderRadiusMd,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGolferRow(
    TournamentGolfer golfer,
    bool isSelected,
    bool isExpanded,
    ThemeData theme,
  ) {
    final isGolferLocked =
        widget.isLocked ||
        (golfer.teeTime != null &&
            DateTime.now().toUtc().isAfter(
              golfer.teeTime!.subtract(const Duration(minutes: 15)),
            ));

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedGolferIds.remove(golfer.id);
              } else {
                _expandedGolferIds.add(golfer.id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                // Selection action button next to name
                if (isGolferLocked)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                            size: 24,
                          )
                        : const Icon(
                            Icons.lock_outline,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () {
                        if (isSelected) {
                          ref
                              .read(draftStateNotifierProvider.notifier)
                              .removeGolfer(golfer);
                        } else {
                          if (widget.replacingGolfer != null) {
                            final success = ref
                                .read(draftStateNotifierProvider.notifier)
                                .replaceGolfer(widget.replacingGolfer!, golfer);
                            if (success) {
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Golfer is already on your roster!',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
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
                          }
                        }
                      },
                      child: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.accent,
                              size: 26,
                            )
                          : const Icon(
                              Icons.add_circle_outline,
                              color: AppColors.primary,
                              size: 26,
                            ),
                    ),
                  ),
                GolferAvatar(profile: golfer.profile, size: 60),
                const SizedBox(width: AppSpacing.sm),
                // Golfer details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              golfer.profile.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (golfer.profile.isAmateur) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.statusScheduledBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'AM',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.statusScheduledText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (golfer.status == 'WD' || golfer.status == 'MC')
                        Text(
                          golfer.status,
                          style: const TextStyle(
                            color: AppColors.scoreBogeyBg,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Row(
                          children: [
                            if (!golfer.profile.isAmateur &&
                                (golfer.profile.eventsPlayed == null ||
                                    golfer.profile.eventsPlayed == 0)) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.statusLiveBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LIV / INTL',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.statusLiveText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (golfer.teeTime != null) ...[
                              if (DateTime.now().toUtc().isAfter(
                                golfer.teeTime!.subtract(
                                  const Duration(minutes: 15),
                                ),
                              )) ...[
                                const Icon(
                                  Icons.lock,
                                  color: AppColors.scoreBogeyBg,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'LOCKED (${_formatTeeTime(golfer.teeTime!)})',
                                  style: const TextStyle(
                                    color: AppColors.scoreBogeyBg,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  _formatTeeTime(golfer.teeTime!),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                // Price & World Rank
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '\$${golfer.price.toStringAsFixed(2)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      golfer.profile.worldRank != null
                          ? 'WR ${golfer.profile.worldRank}'
                          : 'WR -',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.sm,
              left: 34,
              right: 8,
            ), // indent under name
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.alternateRow,
                borderRadius: AppSpacing.borderRadiusMd,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Season Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CURRENT SEASON',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          'Avg Score',
                          (golfer.profile.scoringAvg != null &&
                                  golfer.profile.scoringAvg! > 0)
                              ? golfer.profile.scoringAvg!.toStringAsFixed(1)
                              : '-',
                        ),
                        const SizedBox(height: 4),
                        _buildStatRow(
                          'Events (Rounds)',
                          '${golfer.profile.eventsPlayed ?? 0} (${golfer.profile.roundsPlayed ?? 0})',
                        ),
                        const SizedBox(height: 4),
                        _buildStatRow(
                          'Wins / T10s',
                          '${golfer.profile.wins ?? 0}W / ${golfer.profile.top10s ?? 0}T10',
                        ),
                        const SizedBox(height: 4),
                        _buildStatRow(
                          'Cuts Made',
                          '${golfer.profile.cutsMade ?? 0} / ${golfer.profile.eventsPlayed ?? 0}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Vertical divider
                  Container(height: 80, width: 1, color: AppColors.border),
                  const SizedBox(width: AppSpacing.md),
                  // Prior Season Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PRIOR SEASON',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          'Avg Score',
                          (golfer.profile.priorScoringAvg != null &&
                                  golfer.profile.priorScoringAvg! > 0)
                              ? golfer.profile.priorScoringAvg!.toStringAsFixed(
                                  1,
                                )
                              : '-',
                        ),
                        const SizedBox(height: 4),
                        _buildStatRow(
                          'Events (Rounds)',
                          '${golfer.profile.priorEventsPlayed ?? 0} (${golfer.profile.priorRoundsPlayed ?? 0})',
                        ),
                        const SizedBox(height: 4),
                        _buildStatRow(
                          'Wins / T10s',
                          '${golfer.profile.priorWins ?? 0}W / ${golfer.profile.priorTop10s ?? 0}T10',
                        ),
                        const SizedBox(height: 4),
                        _buildStatRow(
                          'Cuts Made',
                          '${golfer.profile.priorCutsMade ?? 0} / ${golfer.profile.priorEventsPlayed ?? 0}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 150),
        ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedGolfers = ref.watch(draftStateNotifierProvider);
    final sortedGolfers = _getSortedAndFilteredGolfers();

    if (widget.limit != null) {
      // Preview mode (unconstrained height inside Dashboard's scrollview)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: sortedGolfers.map((golfer) {
          final isSelected = selectedGolfers.any((g) => g.id == golfer.id);
          final isExpanded = _expandedGolferIds.contains(golfer.id);
          return _buildGolferRow(golfer, isSelected, isExpanded, theme);
        }).toList(),
      );
    }

    // Full screen search/browse mode (constrained height, uses ListView.builder)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchBar(theme),
        const SizedBox(height: AppSpacing.md),
        _buildSortChips(theme),
        const SizedBox(height: AppSpacing.md),
        if (sortedGolfers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'No golfers match "$_searchQuery"'
                    : 'No golfers available',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: sortedGolfers.length,
              itemBuilder: (context, index) {
                final golfer = sortedGolfers[index];
                final isSelected = selectedGolfers.any(
                  (g) => g.id == golfer.id,
                );
                final isExpanded = _expandedGolferIds.contains(golfer.id);

                return _buildGolferRow(golfer, isSelected, isExpanded, theme);
              },
            ),
          ),
      ],
    );
  }
}
