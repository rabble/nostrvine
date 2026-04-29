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
  /// Tolerates both the legacy shape and the post-funnelcake#238 envelope:
  /// - Legacy: `{"following": [...], "total": int, "has_more": bool}`
  ///   (key varies: `following`, `followers`, or `pubkeys`)
  /// - Envelope: `{"data": [...], "pagination": {"has_more": bool,
  ///   "next_cursor": string}}`
  factory PaginatedPubkeys.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>?;

    // Prefer the envelope `data` key; fall back to endpoint-specific keys.
    final pubkeysData =
        json['data'] as List<dynamic>? ??
        json['following'] as List<dynamic>? ??
        json['followers'] as List<dynamic>? ??
        json['pubkeys'] as List<dynamic>? ??
        <dynamic>[];

    final hasMore =
        json['has_more'] as bool? ?? pagination?['has_more'] as bool? ?? false;

    return PaginatedPubkeys(
      pubkeys: pubkeysData.map((e) => e.toString()).toList(),
      total: json['total'] as int? ?? pubkeysData.length,
      hasMore: hasMore,
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
