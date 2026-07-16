import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// UserProfile model matching the database public.users table.
class UserProfile {
  final String id;
  final String email;
  final String teamName;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.teamName,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      teamName: json['team_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'team_name': teamName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Provider exposing the [SupabaseClient] instance, allows overriding in testing.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// StreamProvider exposing the current authenticated Supabase [AuthState].
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Notifier managing whether the user is in a password recovery flow.
class PasswordRecoveryNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void setRecovery(bool value) {
    state = value;
  }
}

/// Provider tracking whether the user is in a password recovery flow.
final isPasswordRecoveryProvider =
    NotifierProvider<PasswordRecoveryNotifier, bool>(() {
      return PasswordRecoveryNotifier();
    });

/// StreamProvider exposing the current authenticated Supabase [Session].
final authSessionProvider = StreamProvider<Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((data) => data.session);
});

/// FutureProvider that fetches the [UserProfile] for the current authenticated user.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final sessionAsync = ref.watch(authSessionProvider);
  final session = sessionAsync.value;

  if (session == null) {
    return null;
  }

  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('users')
      .select()
      .eq('id', session.user.id)
      .maybeSingle();

  if (response == null) {
    return null;
  }

  return UserProfile.fromJson(response);
});
