import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/spacing.dart';
import '../../widgets/draft_panel.dart';
import '../../widgets/responsive_layout.dart';

/// Screen allowing the user to edit or draft their team golfer roster.
class EditRosterScreen extends ConsumerWidget {
  const EditRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('EDIT ROSTER'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: DraftPanel(
            isLocked: false,
            onSaveSuccess: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}
