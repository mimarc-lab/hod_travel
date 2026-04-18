// =============================================================================
// App-level exception hierarchy
//
// Wraps Supabase / network errors in clear, developer-friendly types.
// Catch AppException at the UI layer — never expose raw PostgrestException.
// =============================================================================

/// Base class for all app-level exceptions.
class AppException implements Exception {
  final String message;
  final Object? cause; // original error, for debugging

  const AppException(this.message, {this.cause});

  @override
  String toString() => 'AppException: $message';
}

/// Thrown when Supabase auth operations fail (wrong password, expired token…).
/// Named AppAuthException to avoid clashing with supabase_flutter's AuthException.
class AppAuthException extends AppException {
  const AppAuthException(super.message, {super.cause});

  @override
  String toString() => 'AppAuthException: $message';
}

/// Thrown when a database read/write fails (network, RLS, constraint…).
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause});

  @override
  String toString() => 'DatabaseException: $message';
}

/// Thrown when a required record does not exist.
class NotFoundException extends AppException {
  final String? entityType;
  final String? entityId;

  const NotFoundException(
    super.message, {
    this.entityType,
    this.entityId,
    super.cause,
  });

  @override
  String toString() => 'NotFoundException: $message'
      '${entityType != null ? " [$entityType${entityId != null ? ':$entityId' : ''}]" : ""}';
}

/// Placeholder — thrown when RLS or role checks deny an action.
/// Expand with role/permission details in Stage 2.
class PermissionException extends AppException {
  const PermissionException(super.message, {super.cause});

  @override
  String toString() => 'PermissionException: $message';
}

// =============================================================================
// Helper — wraps any Supabase/async call in a DatabaseException
// =============================================================================

/// Runs [fn] and re-throws any error as a [DatabaseException].
/// Use inside repository methods to keep error handling consistent.
///
/// ```dart
/// final rows = await guardDb(() => _client.from('trips').select());
/// ```
Future<T> guardDb<T>(Future<T> Function() fn) async {
  try {
    return await fn();
  } on AppException {
    rethrow; // already typed — pass through
  } catch (e) {
    throw DatabaseException(
      _extractMessage(e),
      cause: e,
    );
  }
}

String _extractMessage(Object e) {
  // PostgrestException has a .message field
  try {
    final dynamic d = e;
    final msg = d.message as String?;
    if (msg != null && msg.isNotEmpty) return msg;
  } catch (_) {}
  return e.toString();
}
