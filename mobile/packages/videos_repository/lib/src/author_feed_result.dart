// ABOUTME: Result model for a single author's video feed page.
// ABOUTME: Offset-paginated (distinct from HomeFeedResult's cursor model);
// ABOUTME: carries the Funnelcake v2 envelope (totalCount/nextOffset/hasMore).

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

const Object _unset = Object();

/// {@template author_feed_result}
/// Result of an author/profile video-feed fetch.
///
/// Profile feeds paginate by **offset** and surface the Funnelcake v2
/// envelope ([totalCount]/[nextOffset]/[hasMore]) that the count UI and
/// infinite scroll depend on — intentionally separate from `HomeFeedResult`,
/// whose cursor-based fields (`nextCursor`/`paginationCursor`) do not apply
/// to a single-author feed.
///
/// [videos] are returned **unfiltered** (only NIP-40 expired entries are
/// dropped at the REST ingress). Blocklist / content-preference /
/// Divine-host filtering is applied by the consuming cubit on every emit so
/// block/unblock reflects without a re-fetch (#4782).
/// {@endtemplate}
class AuthorFeedResult extends Equatable {
  /// {@macro author_feed_result}
  const AuthorFeedResult({
    required this.authorPubkey,
    this.videos = const [],
    this.nextOffset,
    this.totalCount,
    this.hasMore,
  });

  /// The author whose feed this page belongs to (full hex pubkey).
  final String authorPubkey;

  /// The videos for this page, merged across REST + relay seed and sorted
  /// newest-first. Unfiltered (see class doc).
  final List<VideoEvent> videos;

  /// Server-provided offset for the next page, or a client-side estimate when
  /// the server omits it. `null` when there is no next page.
  final int? nextOffset;

  /// Total number of videos by this author (from the v2 envelope /
  /// `X-Total-Count`). `null` when the server does not report it.
  final int? totalCount;

  /// Whether more pages are available. `null` when unknown (callers fall back
  /// to a page-size heuristic).
  final bool? hasMore;

  /// Returns a copy with the given fields replaced.
  AuthorFeedResult copyWith({
    String? authorPubkey,
    List<VideoEvent>? videos,
    Object? nextOffset = _unset,
    Object? totalCount = _unset,
    Object? hasMore = _unset,
  }) {
    return AuthorFeedResult(
      authorPubkey: authorPubkey ?? this.authorPubkey,
      videos: videos ?? this.videos,
      nextOffset: identical(nextOffset, _unset)
          ? this.nextOffset
          : nextOffset as int?,
      totalCount: identical(totalCount, _unset)
          ? this.totalCount
          : totalCount as int?,
      hasMore: identical(hasMore, _unset) ? this.hasMore : hasMore as bool?,
    );
  }

  @override
  List<Object?> get props => [
    authorPubkey,
    videos,
    nextOffset,
    totalCount,
    hasMore,
  ];
}
