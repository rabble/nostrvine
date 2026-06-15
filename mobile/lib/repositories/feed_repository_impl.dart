// ABOUTME: Riverpod-backed FeedRepository delegating to existing feed providers.
// ABOUTME: Resolves global feeds (For You/Popular/Classics/New) + static sources.

import 'dart:async';

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:rxdart/rxdart.dart';

/// Identifies one of the four global, keepAlive Riverpod feed providers that
/// [RiverpodFeedRepository] can resolve directly.
enum _GlobalFeed { forYou, popular, classicVines, newVideos }

/// A [FeedRepository] that delegates to the app's existing feed providers and
/// blocs instead of re-implementing pagination.
///
/// It owns the variants that are globally resolvable from a keepAlive [Ref]:
///
/// * the four home tabs ([ForYouViewSource], [PopularViewSource],
///   [ClassicVinesViewSource], [NewVideosViewSource]) — delegated to their
///   `@Riverpod(keepAlive: true)` feed providers, which already apply the
///   block / platform boundary filter in `build()`;
/// * static sources ([SingleVideoViewSource], [VideoListViewSource]) —
///   delegated to a [StaticFeedRepository].
///
/// Scoped, per-widget sources (profile feed and the liked / reposts / saved /
/// collabs sub-feeds, hashtag, search, ...) are owned by their existing blocs.
/// Those surfaces wrap their bloc's stream in a [StreamFeedRepository] at the
/// call site rather than routing through this global repository, because the
/// underlying blocs are constructed per-widget with per-call dependencies and
/// are not reachable from a global [Ref]. Calling [watchView] with one of
/// those sources throws [UnsupportedError]. See issue #3383.
class RiverpodFeedRepository implements FeedRepository {
  RiverpodFeedRepository(this._ref);

  final Ref _ref;

  /// One replayable bridge per global feed, created lazily on first watch and
  /// disposed with the (keepAlive) provider.
  final Map<_GlobalFeed, _GlobalFeedBridge> _bridges = {};

  late final StaticFeedRepository _static = StaticFeedRepository(
    // Static snapshots bypass each feed provider's `build()` filter, so apply
    // the platform boundary here. Block / mute is enforced downstream by the
    // FullscreenFeedBloc's BlockAuthorFilter + the removedVideoIds bus.
    filter: (videos) =>
        videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
  );

  _GlobalFeed? _globalFeedFor(ViewSource source) => switch (source) {
    ForYouViewSource() => _GlobalFeed.forYou,
    PopularViewSource() => _GlobalFeed.popular,
    ClassicVinesViewSource() => _GlobalFeed.classicVines,
    NewVideosViewSource() => _GlobalFeed.newVideos,
    _ => null,
  };

  bool _isStatic(ViewSource source) =>
      source is SingleVideoViewSource || source is VideoListViewSource;

  _GlobalFeedBridge _bridge(_GlobalFeed feed) {
    return _bridges.putIfAbsent(feed, () {
      final bridge = _GlobalFeedBridge();
      void onState(AsyncValue<VideoFeedState> next) {
        final feedState = next.asData?.value;
        if (feedState == null) return;
        bridge.update(
          videos: feedState.videos,
          hasMore: feedState.hasMoreContent,
        );
      }

      // Each feed provider has a distinct generated type, so the listen is
      // wired per-feed rather than through a shared provider-typed helper.
      final subscription = switch (feed) {
        _GlobalFeed.forYou => _ref.listen(
          forYouFeedProvider,
          (_, next) => onState(next),
          fireImmediately: true,
        ),
        _GlobalFeed.popular => _ref.listen(
          popularVideosFeedProvider,
          (_, next) => onState(next),
          fireImmediately: true,
        ),
        _GlobalFeed.classicVines => _ref.listen(
          classicVinesFeedProvider,
          (_, next) => onState(next),
          fireImmediately: true,
        ),
        _GlobalFeed.newVideos => _ref.listen(
          newVideosFeedProvider,
          (_, next) => onState(next),
          fireImmediately: true,
        ),
      };
      _ref.onDispose(() {
        subscription.close();
        bridge.dispose();
      });
      return bridge;
    });
  }

  Future<void> _loadMoreFor(_GlobalFeed feed) => switch (feed) {
    _GlobalFeed.forYou => _ref.read(forYouFeedProvider.notifier).loadMore(),
    _GlobalFeed.popular => _ref
        .read(popularVideosFeedProvider.notifier)
        .loadMore(),
    _GlobalFeed.classicVines => _ref
        .read(classicVinesFeedProvider.notifier)
        .loadMore(),
    _GlobalFeed.newVideos => _ref
        .read(newVideosFeedProvider.notifier)
        .loadMore(),
  };

  @override
  Stream<List<VideoEvent>> watchView(ViewSource source) {
    if (_isStatic(source)) return _static.watchView(source);
    final feed = _globalFeedFor(source);
    if (feed != null) return _bridge(feed).videosStream;
    throw UnsupportedError(
      'RiverpodFeedRepository cannot resolve $source globally; scoped sources '
      'must be wrapped in a StreamFeedRepository at the call site.',
    );
  }

  @override
  Future<void> loadMore(ViewSource source) {
    if (_isStatic(source)) return _static.loadMore(source);
    final feed = _globalFeedFor(source);
    if (feed != null) return _loadMoreFor(feed);
    throw UnsupportedError(
      'RiverpodFeedRepository cannot resolve $source globally; scoped sources '
      'must be wrapped in a StreamFeedRepository at the call site.',
    );
  }

  @override
  Stream<bool> watchHasMore(ViewSource source) {
    if (_isStatic(source)) return _static.watchHasMore(source);
    final feed = _globalFeedFor(source);
    if (feed != null) return _bridge(feed).hasMoreStream;
    throw UnsupportedError(
      'RiverpodFeedRepository cannot resolve $source globally; scoped sources '
      'must be wrapped in a StreamFeedRepository at the call site.',
    );
  }
}

/// Replayable bridge mirroring a single feed provider's latest state.
///
/// Uses [BehaviorSubject] so a fullscreen route that subscribes after the feed
/// has already loaded still receives the current list immediately — matching
/// the pre-existing `NewVideosFullscreenFeedBridge` behaviour.
class _GlobalFeedBridge {
  final BehaviorSubject<List<VideoEvent>> _videos =
      BehaviorSubject<List<VideoEvent>>();
  final BehaviorSubject<bool> _hasMore = BehaviorSubject<bool>();

  Stream<List<VideoEvent>> get videosStream => _videos.stream;

  Stream<bool> get hasMoreStream => _hasMore.stream;

  void update({required List<VideoEvent> videos, required bool hasMore}) {
    _videos.add(List<VideoEvent>.unmodifiable(videos));
    _hasMore.add(hasMore);
  }

  void dispose() {
    _videos.close();
    _hasMore.close();
  }
}
