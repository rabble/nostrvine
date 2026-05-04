// ABOUTME: Exception types for the identity verification client.
// ABOUTME: Surfaces transport and non-2xx HTTP failures to callers.

/// Raised when the identity-verification service returns a non-2xx
/// response or the request fails before reaching the server.
class IdentityVerificationException implements Exception {
  /// Creates a new [IdentityVerificationException].
  IdentityVerificationException(this.message, {this.statusCode, this.cause});

  /// Human-readable description of the failure.
  final String message;

  /// The HTTP status code when the failure was a non-2xx response.
  final int? statusCode;

  /// The underlying cause when the failure was a transport error.
  final Object? cause;

  @override
  String toString() =>
      'IdentityVerificationException(${statusCode ?? '-'}): $message';
}
