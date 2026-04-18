import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/team_repository.dart';

// =============================================================================
// AuthRepository — clean interface over Supabase auth
//
// Separated from AuthProvider (UI state) so this logic can be used from
// any context (provider, service, test) without a BuildContext.
// =============================================================================

abstract class AuthRepository {
  /// Sign in with email + password. Throws [AppAuthException] on failure.
  Future<void> signInWithEmail(String email, String password);

  /// Sign out the current user.
  Future<void> signOut();

  /// Send a password reset email. Throws [AppAuthException] on failure.
  Future<void> sendPasswordReset(String email);

  /// Returns the currently authenticated Supabase user, or null.
  User? get currentUser;

  /// Returns the current session, or null if not signed in.
  Session? get currentSession;

  /// Stream of auth state changes — use in AuthProvider or app root.
  Stream<AuthState> get authStateChanges;

  /// Ensure the profiles row exists for [userId].
  /// Called after sign-in or sign-up to guarantee the row is present.
  /// Safe to call multiple times — uses upsert.
  Future<void> ensureProfileExists(User user);

  /// Bootstrap helper called once after a user's very first sign-in.
  /// Creates profile row + adds user to [teamId] with [role].
  Future<AppUser> bootstrapNewUser({
    required User user,
    required String teamId,
    required AppRole role,
  });

  /// Load the full AppUser for [userId], joined with their team role.
  /// Returns a minimal AppUser from auth data if the profile row is missing.
  Future<AppUser> loadAppUser(String userId, {String? teamId});
}

// =============================================================================
// Supabase implementation
// =============================================================================

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  final ProfileRepository _profiles;
  final TeamRepository _teams;

  SupabaseAuthRepository({
    required SupabaseClient client,
    required ProfileRepository profiles,
    required TeamRepository teams,
  })  : _client = client,
        _profiles = profiles,
        _teams = teams;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Sign in ─────────────────────────────────────────────────────────────────

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw AppAuthException(e.message, cause: e);
    } catch (e) {
      throw AppAuthException('Sign-in failed. Please try again.', cause: e);
    }
  }

  // ── Sign out ─────────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw AppAuthException('Sign-out failed.', cause: e);
    }
  }

  // ── Password reset ───────────────────────────────────────────────────────────

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw AppAuthException(e.message, cause: e);
    } catch (e) {
      throw AppAuthException('Could not send reset email.', cause: e);
    }
  }

  // ── Profile bootstrap ────────────────────────────────────────────────────────

  @override
  Future<void> ensureProfileExists(User user) async {
    try {
      final existing = await _profiles.fetchProfile(user.id);
      if (existing != null) return;

      final name = user.userMetadata?['full_name'] as String? ??
          user.email?.split('@').first ?? '';
      await _profiles.upsertProfile(ProfileRow(
        id:       user.id,
        fullName: name,
        email:    user.email ?? '',
      ));
    } catch (e) {
      // Non-fatal — profile trigger may have already created the row.
      // Log in production; don't crash sign-in flow.
    }
  }

  @override
  Future<AppUser> bootstrapNewUser({
    required User user,
    required String teamId,
    required AppRole role,
  }) async {
    await ensureProfileExists(user);

    await _teams.addMember(
      teamId: teamId,
      userId: user.id,
      role: role,
    );

    return loadAppUser(user.id, teamId: teamId);
  }

  // ── Load AppUser ─────────────────────────────────────────────────────────────

  @override
  Future<AppUser> loadAppUser(String userId, {String? teamId}) async {
    final profile = await _profiles.fetchProfile(userId);
    AppRole role = AppRole.staff;

    if (teamId != null) {
      try {
        final members = await _teams.fetchMembers(teamId);
        final member = members.where((m) => m.userId == userId).firstOrNull;
        if (member != null) role = member.role;
      } catch (_) {}
    }

    if (profile != null) return profile.toAppUser(role: role);

    // Fallback: build minimal user from Supabase auth data
    final authUser = _client.auth.currentUser;
    final email = authUser?.email ?? '';
    final name = authUser?.userMetadata?['full_name'] as String? ?? email;
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';

    return AppUser(
      id:          userId,
      name:        name.isNotEmpty ? name : email,
      initials:    initials,
      avatarColor: avatarColorFor(userId.codeUnits.fold(0, (a, b) => a + b)),
      role:        role.label,
      appRole:     role,
    );
  }
}
