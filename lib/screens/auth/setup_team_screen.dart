import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_providers.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/responsive_layout.dart';

class SetupTeamScreen extends ConsumerStatefulWidget {
  const SetupTeamScreen({super.key});

  @override
  ConsumerState<SetupTeamScreen> createState() => _SetupTeamScreenState();
}

class _SetupTeamScreenState extends ConsumerState<SetupTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final teamName = _teamNameController.text.trim();
    final client = ref.read(supabaseClientProvider);
    final session = ref.read(authSessionProvider).value;

    if (session == null) {
      setState(() {
        _errorMessage =
            'Authentication session not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      // 1. Pre-check for case-insensitive team name uniqueness
      final existingNameCheck = await client
          .from('users')
          .select('id')
          .ilike('team_name', teamName)
          .maybeSingle();

      if (existingNameCheck != null && mounted) {
        setState(() {
          _errorMessage =
              'This team name is already taken. Please choose another one.';
          _isLoading = false;
        });
        return;
      }

      // 2. Perform the database insert
      await client.from('users').insert({
        'id': session.user.id,
        'email': session.user.email,
        'team_name': teamName,
      });

      // 3. Invalidate the userProfileProvider to trigger routing update
      ref.invalidate(userProfileProvider);
    } on PostgrestException catch (e) {
      // 23505 is PostgreSQL code for unique violation
      if (e.code == '23505') {
        setState(() {
          _errorMessage =
              'This team name is already taken. Please choose another one.';
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to create team: ${e.message}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await ref.read(supabaseClientProvider).auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to log out: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('TEAM SETUP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _isLoading ? null : _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.group_add_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Name Your Team',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Every manager needs a unique franchise name to compete.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                BbmCard(
                  glassmorphic: true,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _teamNameController,
                          maxLength: 25,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(25),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Team Name',
                            hintText: 'e.g. Green Jacket Chasers',
                            prefixIcon: Icon(
                              Icons.shield_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a team name';
                            }
                            final trimmed = value.trim();
                            if (trimmed.length > 25) {
                              return 'Team name cannot exceed 25 characters';
                            }
                            final regex = RegExp(r'^[a-zA-Z0-9 _-]+$');
                            if (!regex.hasMatch(trimmed)) {
                              return 'Alphanumeric, spaces, dashes (-), and underscores (_) only';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.scoreBogeyBg.withValues(
                                alpha: 0.1,
                              ),
                              border: Border.all(
                                color: AppColors.scoreBogeyBg,
                                width: 1,
                              ),
                              borderRadius: AppSpacing.borderRadiusMd,
                            ),
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.scoreBogeyBg,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        BbmButton(
                          text: 'Create Team',
                          isLoading: _isLoading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextButton(
                  onPressed: _isLoading ? null : _logout,
                  child: Text(
                    'Cancel & Sign Out',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
