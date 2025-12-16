// ABOUTME: Data model for NIP-45 COUNT responses from relays.
// ABOUTME: Contains the count value and whether it's approximate.

/// Response from a NIP-45 COUNT query
class CountResponse {
  /// The count of matching events
  final int count;

  /// Whether this count is approximate (probabilistic)
  final bool approximate;

  const CountResponse({required this.count, this.approximate = false});

  @override
  String toString() =>
      'CountResponse(count: $count, approximate: $approximate)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountResponse &&
          count == other.count &&
          approximate == other.approximate;

  @override
  int get hashCode => Object.hash(count, approximate);
}

/// Exception thrown when a relay doesn't support COUNT queries (NIP-45)
class CountNotSupportedException implements Exception {
  final String reason;

  CountNotSupportedException(this.reason);

  @override
  String toString() => 'CountNotSupportedException: $reason';
}
