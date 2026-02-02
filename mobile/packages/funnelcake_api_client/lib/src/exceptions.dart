// ABOUTME: Exception classes for the Funnelcake API client.
// ABOUTME: Provides typed exceptions for HTTP API operations.

/// Base exception for all Funnelcake API errors.
class FunnelcakeException implements Exception {
  /// Creates a new Funnelcake exception.
  const FunnelcakeException(this.message);

  /// The error message describing what went wrong.
  final String message;

  @override
  String toString() => 'FunnelcakeException: $message';
}

/// Exception thrown when the Funnelcake API is not configured.
///
/// This occurs when the client is instantiated with an empty base URL.
class FunnelcakeNotConfiguredException extends FunnelcakeException {
  /// Creates a new not configured exception.
  const FunnelcakeNotConfiguredException()
    : super('Funnelcake API not configured');

  @override
  String toString() => 'FunnelcakeNotConfiguredException: $message';
}

/// Exception thrown when an API request fails.
///
/// Includes the HTTP status code and optionally the URL that was requested.
class FunnelcakeApiException extends FunnelcakeException {
  /// Creates a new API exception.
  const FunnelcakeApiException({
    required String message,
    required this.statusCode,
    this.url,
  }) : super(message);

  /// The HTTP status code returned by the server.
  final int statusCode;

  /// The URL that was requested (if available).
  final String? url;

  @override
  String toString() => 'FunnelcakeApiException: $message (status: $statusCode)';
}

/// Exception thrown when a resource is not found (HTTP 404).
class FunnelcakeNotFoundException extends FunnelcakeApiException {
  /// Creates a new not found exception.
  FunnelcakeNotFoundException({required String resource, super.url})
    : super(message: '$resource not found', statusCode: 404);

  @override
  String toString() => 'FunnelcakeNotFoundException: $message';
}

/// Exception thrown when a request times out.
class FunnelcakeTimeoutException extends FunnelcakeException {
  /// Creates a new timeout exception.
  const FunnelcakeTimeoutException([this.url])
    : super('Request timed out${url != null ? ' for $url' : ''}');

  /// The URL that was requested (if available).
  final String? url;

  @override
  String toString() => 'FunnelcakeTimeoutException: $message';
}
