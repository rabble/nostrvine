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

/// Thrown when publishing or querying sync index events fails.
class SyncIndexException implements Exception {
  /// Creates a [SyncIndexException].
  SyncIndexException(this.message);

  /// Human-readable cause, safe for logs.
  final String message;

  @override
  String toString() => 'SyncIndexException: $message';
}
