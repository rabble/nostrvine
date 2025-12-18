// ABOUTME: Authentication-related exceptions
// ABOUTME: Provides typed exceptions for auth-required operations

/// Exception thrown when an operation requires authentication but user is not
/// authenticated.
///
/// Operations that require a signed-in user with valid keypair should throw
/// this exception when attempted without authentication.
class NotAuthenticatedException implements Exception {
  const NotAuthenticatedException([this.message = 'User not authenticated']);

  final String message;

  @override
  String toString() => 'NotAuthenticatedException: $message';
}
