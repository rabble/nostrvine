// ABOUTME: Typed exceptions thrown by the creator_sync clients.
// ABOUTME: Callers catch these; the repository decides fallback behaviour.

/// Thrown when a sealed sync payload cannot be authenticated or decrypted.
class SyncDecryptException implements Exception {
  /// Creates a [SyncDecryptException].
  SyncDecryptException(this.message);

  /// Human-readable cause, safe for logs. Never contains plaintext.
  final String message;

  @override
  String toString() => 'SyncDecryptException: $message';
}

/// Thrown when the vault key cannot be obtained for the active account.
class VaultKeyUnavailableException implements Exception {
  /// Creates a [VaultKeyUnavailableException].
  VaultKeyUnavailableException(this.message);

  /// Human-readable cause, safe for logs.
  final String message;

  @override
  String toString() => 'VaultKeyUnavailableException: $message';
}

/// Thrown when the device-local store backing a sync bucket cannot be read.
///
/// Distinct from "the store is empty": an empty store is a fact to sync,
/// while an unreadable one carries no information about what the user has.
/// Reconciliation treats this as a transient failure and retries later,
/// because the alternative — reading it as an empty library — publishes a
/// tombstone for every item the account has and deletes them everywhere.
class LocalStoreUnreadableException implements Exception {
  /// Creates a [LocalStoreUnreadableException].
  LocalStoreUnreadableException(this.message);

  /// Human-readable cause, safe for logs.
  final String message;

  @override
  String toString() => 'LocalStoreUnreadableException: $message';
}

/// Thrown when publishing or querying sync index events fails.
class SyncIndexException implements Exception {
  /// Creates a [SyncIndexException].
  SyncIndexException(this.message);

  /// Human-readable cause, safe for logs.
  final String message;

  @override
  String toString() => 'SyncIndexException: $message';
}
