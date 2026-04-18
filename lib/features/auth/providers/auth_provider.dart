import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/profile_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthStatus
// ─────────────────────────────────────────────────────────────────────────────

enum AuthStatus { loading, authenticated, unauthenticated }

// ─────────────────────────────────────────────────────────────────────────────
// AuthProvider
// Loads profile + team membership after sign-in.
// Exposes: currentUser (with correct appRole), teamId, status.
// Sets AppRepositories.currentTeamId and currentAppUser for screens that
// need team context without explicit constructor injection.
// ─────────────────────────────────────────────────────────────────────────────

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.loading;
  AppUser?   _currentUser;
  String?    _teamId;
  String?    _errorMessage;

  AuthStatus get status       => _status;
  AppUser?   get currentUser  => _currentUser;
  String?    get teamId       => _teamId;
  String?    get errorMessage => _errorMessage;
  bool get isAuthenticated    => _status == AuthStatus.authenticated;

  AuthProvider() {
    _init();
  }

  // ── Initialise from existing session ──────────────────────────────────────

  Future<void> _init() async {
    // Supabase was not initialized (no --dart-define credentials provided).
    if (AppRepositories.instance == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    final session = db.auth.currentSession;
    if (session != null) {
      await _loadSession(session.user);
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }

    // Listen for auth state changes
    db.auth.onAuthStateChange.listen((data) async {
      final event   = data.event;
      final session = data.session;
      if (event == AuthChangeEvent.signedIn && session != null) {
        await _loadSession(session.user);
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _teamId      = null;
        _clearRepoSession();
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
    });
  }

  // ── Session load: profile + team ─────────────────────────────────────────

  Future<void> _loadSession(User supaUser) async {
    try {
      final repos = AppRepositories.instance;
      ProfileRow? profile;
      AppRole role = AppRole.staff;
      String? teamId;

      if (repos != null) {
        // 1. Load profile
        profile = await repos.profiles.fetchProfile(supaUser.id);

        // 2. Load teams (picks first active team)
        try {
          final teams = await repos.teams.fetchMyTeams();
          if (teams.isNotEmpty) {
            teamId = teams.first.id;

            // 3. Load role in that team
            final members = await repos.teams.fetchMembers(teamId);
            final me = members
                .where((m) => m.userId == supaUser.id)
                .firstOrNull;
            if (me != null) role = me.role;
          }
        } catch (_) {
          // Non-fatal — proceed with default staff role and no team
        }
      }

      // 4. Build AppUser
      if (profile != null) {
        _currentUser = profile.toAppUser(role: role);
      } else {
        // Profile row not yet created — build minimal from auth data
        final email = supaUser.email ?? '';
        final name  = supaUser.userMetadata?['full_name'] as String? ?? email;
        final initials = name.isNotEmpty
            ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
            : '?';
        _currentUser = AppUser(
          id:          supaUser.id,
          name:        name.isNotEmpty ? name : email,
          initials:    initials,
          avatarColor: avatarColorFor(
              supaUser.id.codeUnits.fold(0, (a, b) => a + b)),
          role:        role.label,
          appRole:     role,
        );
      }

      _teamId = teamId;
      _status = AuthStatus.authenticated;

      // 5. Push into AppRepositories so screens can access without threading
      _pushToRepoSession();
    } catch (_) {
      // Still mark as authenticated so the UI isn't stuck on splash
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  void _pushToRepoSession() {
    final repos = AppRepositories.instance;
    if (repos == null) return;
    repos.currentTeamId  = _teamId;
    repos.currentAppUser = _currentUser;
  }

  void _clearRepoSession() {
    final repos = AppRepositories.instance;
    if (repos == null) return;
    repos.currentTeamId  = null;
    repos.currentAppUser = null;
    repos.permissions.invalidate();
  }

  // ── Sign in ────────────────────────────────────────────────────────────────

  Future<bool> signIn(String email, String password) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await db.auth.signInWithPassword(email: email, password: password);
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await db.auth.signOut();
  }

  // ── Password reset ────────────────────────────────────────────────────────

  Future<bool> sendPasswordReset(String email) async {
    _errorMessage = null;
    try {
      await db.auth.resetPasswordForEmail(email);
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Could not send reset email. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
