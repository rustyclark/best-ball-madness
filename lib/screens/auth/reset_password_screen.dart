import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_providers.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/responsive_layout.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

    final password = _passwordController.text.trim();

    try {
      final client = ref.read(supabaseClientProvider);

      // Update password in Supabase
      await client.auth.updateUser(UserAttributes(password: password));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: AppColors.primary,
          ),
        );
        // Turn off password recovery mode to navigate to the dashboard
        ref.read(isPasswordRecoveryProvider.notifier).setRecovery(false);
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
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

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.signOut();
      if (mounted) {
        ref.read(isPasswordRecoveryProvider.notifier).setRecovery(false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: AppColors.scoreBogeyBg,
          ),
        );
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
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_reset_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'RESET PASSWORD',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose a secure new password for your account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Card containing the form
                BbmCard(
                  glassmorphic: true,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ENTER NEW PASSWORD',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.trim().length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Confirm Password Field
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value.trim() !=
                                _passwordController.text.trim()) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Error Banner
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

                        // Submit Button
                        BbmButton(
                          text: 'Update Password',
                          isLoading: _isLoading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                TextButton(
                  onPressed: _isLoading ? null : _signOut,
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
