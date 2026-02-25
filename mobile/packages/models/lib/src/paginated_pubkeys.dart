import 'package:meta/meta.dart';

/// A paginated list of pubkeys from the Funnelcake API.
///
/// Used for follower/following list responses which may be paginated.
@immutable
class PaginatedPubkeys {
  /// Creates a new [PaginatedPubkeys] instance.
  const PaginatedPubkeys({
    required this.pubkeys,
    this.total = 0,
    this.hasMore = false,
  });

  /// Creates a [PaginatedPubkeys] from JSON response.
  ///
  /// The Funnelcake API uses context-specific keys:
  /// - `/following` returns `{"following": [...]}`
  /// - `/followers` returns `{"followers": [...]}`
  /// - Falls back to `"pubkeys"` for generic responses
  factory PaginatedPubkeys.fromJson(Map<String, dynamic> json) {
    final pubkeysData =
        json['following'] as List<dynamic>? ??
        json['followers'] as List<dynamic>? ??
        json['pubkeys'] as List<dynamic>? ??
        <dynamic>[];
    return PaginatedPubkeys(
      pubkeys: pubkeysData.map((e) => e.toString()).toList(),
      total: json['total'] as int? ?? pubkeysData.length,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  /// An empty [PaginatedPubkeys] with no results.
  static const empty = PaginatedPubkeys(pubkeys: []);

  /// The list of public keys.
  final List<String> pubkeys;

  /// Total number of results available (may exceed [pubkeys] length).
  final int total;

  /// Whether more results are available for pagination.
  final bool hasMore;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PaginatedPubkeys) return false;
    if (other.total != total || other.hasMore != hasMore) return false;
    if (other.pubkeys.length != pubkeys.length) return false;
    for (var i = 0; i < pubkeys.length; i++) {
      if (other.pubkeys[i] != pubkeys[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(pubkeys), total, hasMore);

  @override
  String toString() =>
      'PaginatedPubkeys(count: ${pubkeys.length}, '
      'total: $total, hasMore: $hasMore)';
}
