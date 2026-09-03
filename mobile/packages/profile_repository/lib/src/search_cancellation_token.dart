// ABOUTME: Cooperative cancellation token for progressive profile searches.
// ABOUTME: Lets superseded UI searches stop before starting later work.

/// A lightweight cooperative cancellation signal for one search lifecycle.
class SearchCancellationToken {
  /// Creates a token with a privacy-safe correlation identifier.
  SearchCancellationToken(this.correlationId);

  /// Session-local identifier that never contains query text or identities.
  final String correlationId;

  bool _isCancelled = false;

  /// Whether the owner has superseded or disposed this search.
  bool get isCancelled => _isCancelled;

  /// Requests cancellation. Safe to call more than once.
  void cancel() => _isCancelled = true;
}
