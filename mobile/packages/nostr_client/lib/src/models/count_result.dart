// ABOUTME: High-level result model for NIP-45 COUNT queries.
// ABOUTME: Wraps the count value with source tracking and metadata.

import 'package:equatable/equatable.dart';

/// Source of the count result
enum CountSource {
  /// Count came from local cache
  cache,

  /// Count came from gateway REST API
  gateway,

  /// Count came from WebSocket relay (NIP-45)
  websocket,

  /// Count was computed client-side by fetching events
  clientSide,
}

/// Result of a COUNT query (NIP-45)
///
/// Contains the count of matching events, along with metadata about
/// whether the count is approximate and where it came from.
class CountResult extends Equatable {
  /// {@macro CountResult}
  const CountResult({
    required this.count,
    this.approximate = false,
    this.source = CountSource.websocket,
  });

  /// The count of matching events
  final int count;

  /// Whether this count is approximate (probabilistic)
  ///
  /// Some relays may use probabilistic counting for performance reasons.
  /// When true, the count should be treated as an estimate.
  final bool approximate;

  /// Source of the count
  ///
  /// Indicates where the count came from - useful for debugging
  /// and understanding cache behavior.
  final CountSource source;

  /// Creates a copy with optional field overrides
  CountResult copyWith({
    int? count,
    bool? approximate,
    CountSource? source,
  }) {
    return CountResult(
      count: count ?? this.count,
      approximate: approximate ?? this.approximate,
      source: source ?? this.source,
    );
  }

  @override
  List<Object?> get props => [count, approximate, source];
}
