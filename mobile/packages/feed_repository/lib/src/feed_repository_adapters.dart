// ABOUTME: Reusable FeedRepository adapters for static and stream-backed feeds.
// ABOUTME: Let scoped surfaces satisfy the FeedRepository contract locally.

import 'dart:async';

import 'package:feed_repository/src/feed_repository.dart';
import 'package:feed_repository/src/view_source.dart';
import 'package:models/models.dart';

/// A [FeedRepository] backed by a fixed, non-paginating list of videos.
///
/// Used for [SingleVideoViewSource] / [VideoListViewSource] and any surface
/// that only ever shows a frozen snapshot. An optional `filter` is applied at
/// the boundary so a deleted / blocked author still drops out.
class StaticFeedRepository implements FeedRepository {
  /// Creates a static feed repository.
  ///
  /// [filter] is applied to the resolved list at the boundary, e.g. to drop
  /// unsupported, deleted, or blocked-author videos.
  StaticFeedRepository({List<VideoEvent> Function(List<VideoEvent>)? filter})
    : _filter = filter;

  final List<VideoEvent> Function(List<VideoEvent>)? _filter;

  List<VideoEvent> _resolve(ViewSource source) {
    final videos = switch (source) {
      SingleVideoViewSource(:final video) => [video],
      VideoListViewSource(:final videos) => videos,
      _ => throw ArgumentError(
        'StaticFeedRepository cannot resolve $source; it only supports '
        'SingleVideoViewSource and VideoListViewSource.',
      ),
    };
    final filter = _filter;
    return filter == null ? videos : filter(videos);
  }

  @override
  Stream<List<VideoEvent>> watchView(ViewSource source) =>
      Stream<List<VideoEvent>>.value(_resolve(source));

  @override
  Future<void> loadMore(ViewSource source) async {}

  @override
  Stream<bool> watchHasMore(ViewSource source) => Stream<bool>.value(false);
}

/// A [FeedRepository] adapter that wraps an existing video/has-more stream and
/// load-more callback owned by a scoped source (a profile cubit, a sub-feed
/// bloc, ...).
///
/// This lets a surface that already has a live feed bloc satisfy the
/// [FeedRepository] contract without re-implementing pagination. The adapter
/// ignores the [ViewSource] argument — it is already bound to one source — so
/// the caller is responsible for constructing one adapter per source.
///
/// An optional `filter` is applied to every emitted list at the boundary.
class StreamFeedRepository implements FeedRepository {
  /// Creates a stream-backed feed repository bound to a single source.
  ///
  /// [videos] is the live list stream; [hasMore] the pagination flag stream;
  /// [onLoadMore] triggers the next page; [filter] is applied at the boundary.
  StreamFeedRepository({
    required Stream<List<VideoEvent>> videos,
    Stream<bool>? hasMore,
    Future<void> Function()? onLoadMore,
    List<VideoEvent> Function(List<VideoEvent>)? filter,
  }) : _videos = videos,
       _hasMore = hasMore,
       _onLoadMore = onLoadMore,
       _filter = filter;

  final Stream<List<VideoEvent>> _videos;
  final Stream<bool>? _hasMore;
  final Future<void> Function()? _onLoadMore;
  final List<VideoEvent> Function(List<VideoEvent>)? _filter;

  @override
  Stream<List<VideoEvent>> watchView(ViewSource source) {
    final filter = _filter;
    if (filter == null) return _videos;
    return _videos.map(filter);
  }

  @override
  Future<void> loadMore(ViewSource source) async => _onLoadMore?.call();

  @override
  Stream<bool> watchHasMore(ViewSource source) =>
      _hasMore ?? Stream<bool>.value(false);
}
