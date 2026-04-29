// ABOUTME: BLoC for fullscreen video feed playback
// ABOUTME: Receives video stream from source, manages playback index and pagination
// ABOUTME: Handles cache resolution and background caching

import 'dart:async';
import 'dart:collection';
import 'dart:ui' show VoidCallback;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_cache/media_cache.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/services/media_availability_checker.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:unified_logger/unified_logger.dart';

part 'fullscreen_feed_event.dart';
part 'fullscreen_feed_state.dart';

/// Callback invoked by [FullscreenFeedBloc] to purge a confirmed-missing
/// video from the shared VideoEventService caches.
///
/// A callback keeps the BLoC free of direct dependencies on concrete
/// services (matches the existing [FullscreenFeedBloc.onLoadMore] pattern).
typedef OnRemoveVideo = void Function(String videoId);

/// Maximum number of concurrent background cache downloads.
///
/// Limiting to 1 prevents background caching from competing with the
/// foreground video stream for bandwidth, which causes jittery playback
/// on first load.
const _maxConcurrentCacheDownloads = 1;

/// BLoC for managing fullscreen video feed playback.
///
/// This BLoC acts as a bridge between various video sources (profile feed,
/// liked videos, reposts, etc.) and the fullscreen video player UI.
///
/// It receives:
/// - A [Stream] of videos from the source (for reactive updates)
/// - An optional [onLoadMore] callback to trigger pagination on the source
/// - An [initialIndex] for starting playback position
/// - A [MediaCacheManager] for cache resolution and background caching
/// - An optional [BlossomAuthService] for authenticated content caching
///
/// The source BLoC/provider remains the single source of truth for the video
/// list. This BLoC only manages fullscreen-specific state (current index,
/// loading indicators).
///
/// **Playback hooks integration:**
/// - Background caching triggered via [FullscreenFeedVideoCacheStarted]
/// - Loop enforcement handled by [VideoFeedController.maxLoopDuration]
/// - Cache resolution happens at the player level (individual_video_providers)
class FullscreenFeedBloc
    extends Bloc<FullscreenFeedEvent, FullscreenFeedState> {
  FullscreenFeedBloc({
    required Stream<List<VideoEvent>> videosStream,
    required int initialIndex,
    Stream<bool>? hasMoreStream,
    Stream<String>? removedIdsStream,
    MediaCacheManager? mediaCache,
    VoidCallback? onLoadMore,
    BlossomAuthService? blossomAuthService,
    OnRemoveVideo? onRemoveVideo,
    MediaAvailabilityChecker? availabilityChecker,
  }) : _videosStream = videosStream,
       _hasMoreStream = hasMoreStream,
       _removedIdsStream = removedIdsStream,
       _onLoadMore = onLoadMore,
       _mediaCache = mediaCache,
       _blossomAuthService = blossomAuthService,
       _onRemoveVideo = onRemoveVideo,
       _availabilityChecker =
           availabilityChecker ?? const MediaAvailabilityChecker(),
       super(FullscreenFeedState(currentIndex: initialIndex)) {
    on<FullscreenFeedStarted>(_onStarted);
    on<FullscreenFeedHasMoreChanged>(_onHasMoreChanged);
    on<FullscreenFeedLoadMoreRequested>(_onLoadMoreRequested);
    on<FullscreenFeedIndexChanged>(_onIndexChanged);
    on<FullscreenFeedVideoCacheStarted>(_onVideoCacheStarted);
    // Sequential: the HEAD check is async and the dedupe decision depends
    // on previously-removed ids, so two concurrent unavailable events for
    // different videos must not overlap.
    on<FullscreenFeedVideoUnavailable>(
      _onVideoUnavailable,
      transformer: sequential(),
    );
    // Sequential: removal mutates videos + currentIndex + removedVideoIds
    // together; concurrent emits for different ids must not interleave.
    on<FullscreenFeedVideoRemoved>(
      _onVideoRemoved,
      transformer: sequential(),
    );
    on<FullscreenFeedSkipAcknowledged>(_onSkipAcknowledged);
  }

  final Stream<List<VideoEvent>> _videosStream;
  final Stream<bool>? _hasMoreStream;
  final Stream<String>? _removedIdsStream;
  final VoidCallback? _onLoadMore;
  final MediaCacheManager? _mediaCache;
  final BlossomAuthService? _blossomAuthService;
  final OnRemoveVideo? _onRemoveVideo;
  final MediaAvailabilityChecker _availabilityChecker;
  StreamSubscription<bool>? _hasMoreSubscription;
  StreamSubscription<String>? _removedIdsSubscription;

  /// Queue of video IDs waiting to be cached in the background.
  final Queue<_CacheRequest> _cacheQueue = Queue<_CacheRequest>();

  /// Number of downloads currently in progress.
  int _activeCacheDownloads = 0;

  /// Handle feed started - subscribe to the videos stream using emit.forEach.
  ///
  /// emit.forEach automatically:
  /// - Subscribes to the stream
  /// - Emits states for each data event
  /// - Cancels the subscription when the bloc is closed
  ///
  /// Cache resolution is handled at the player level by
  /// individualVideoControllerProvider, not here.
  Future<void> _onStarted(
    FullscreenFeedStarted event,
    Emitter<FullscreenFeedState> emit,
  ) async {
    _hasMoreSubscription ??= _hasMoreStream?.listen(
      (hasMore) {
        if (!isClosed) add(FullscreenFeedHasMoreChanged(hasMore));
      },
      onError: (Object error, StackTrace stackTrace) {
        Log.error(
          'FullscreenFeedBloc: hasMore stream error - $error',
          name: 'FullscreenFeedBloc',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    // Side-channel: deletion (and future block / mute) emits a removed
    // id here. The source-list stream may not be alive (the launching
    // widget may have unmounted on shell-route transition), so the bus
    // is what guarantees the fullscreen drops a removed video without
    // waiting for an app restart.
    _removedIdsSubscription ??= _removedIdsStream?.listen(
      (videoId) {
        if (!isClosed) add(FullscreenFeedVideoRemoved(videoId));
      },
      onError: (Object error, StackTrace stackTrace) {
        Log.error(
          'FullscreenFeedBloc: removedIds stream error - $error',
          name: 'FullscreenFeedBloc',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    await emit.forEach<List<VideoEvent>>(
      _videosStream,
      onData: (videos) {
        Log.debug(
          'FullscreenFeedBloc: Videos updated, count=${videos.length}',
          name: 'FullscreenFeedBloc',
          category: LogCategory.video,
        );

        // Clamp current index to valid range
        final clampedIndex = videos.isEmpty
            ? 0
            : state.currentIndex.clamp(0, videos.length - 1);

        return state.copyWith(
          status: FullscreenFeedStatus.ready,
          videos: videos,
          currentIndex: clampedIndex,
          isLoadingMore: false,
        );
      },
      onError: (error, stackTrace) {
        Log.error(
          'FullscreenFeedBloc: Stream error - $error',
          name: 'FullscreenFeedBloc',
          category: LogCategory.video,
        );
        // Return current state to keep showing existing videos
        return state;
      },
    );
  }

  void _onHasMoreChanged(
    FullscreenFeedHasMoreChanged event,
    Emitter<FullscreenFeedState> emit,
  ) {
    emit(
      state.copyWith(
        canLoadMore: event.hasMore,
        isLoadingMore: state.isLoadingMore && event.hasMore,
      ),
    );
  }

  /// Handle load more request - trigger the source's pagination.
  void _onLoadMoreRequested(
    FullscreenFeedLoadMoreRequested event,
    Emitter<FullscreenFeedState> emit,
  ) {
    final onLoadMore = _onLoadMore;
    if (onLoadMore == null || state.isLoadingMore) return;

    Log.debug(
      'FullscreenFeedBloc: Load more requested',
      name: 'FullscreenFeedBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(isLoadingMore: true));
    try {
      onLoadMore();
    } catch (error, stackTrace) {
      Log.error(
        'FullscreenFeedBloc: Load more callback failed',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
    // isLoadingMore will be reset when _onVideosUpdated is called
  }

  /// Handle index changed (user swiped to a different video).
  void _onIndexChanged(
    FullscreenFeedIndexChanged event,
    Emitter<FullscreenFeedState> emit,
  ) {
    if (event.index == state.currentIndex) return;

    final clampedIndex = state.videos.isEmpty
        ? 0
        : event.index.clamp(0, state.videos.length - 1);

    emit(state.copyWith(currentIndex: clampedIndex));
  }

  /// Handle video ready for caching - enqueue for background caching.
  ///
  /// Called when the video player signals a video is ready for playback.
  /// Downloads are queued and processed one at a time to avoid competing
  /// with the foreground video stream for bandwidth.
  Future<void> _onVideoCacheStarted(
    FullscreenFeedVideoCacheStarted event,
    Emitter<FullscreenFeedState> emit,
  ) async {
    if (event.index < 0 || event.index >= state.videos.length) return;

    final video = state.videos[event.index];
    final cache = _mediaCache;
    if (cache == null) return;

    // Skip if already cached
    if (cache.getCachedFileSync(video.id) != null) {
      Log.debug(
        'FullscreenFeedBloc: Video ${video.id} already cached, skipping',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
      );
      return;
    }

    final videoUrl = video.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      Log.warning(
        'FullscreenFeedBloc: Video ${video.id} has no URL, cannot cache',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
      );
      return;
    }

    // Guard: only cache HTTP URLs (never local file paths)
    if (!videoUrl.startsWith('http://') && !videoUrl.startsWith('https://')) {
      Log.warning(
        'FullscreenFeedBloc: Video ${video.id} has non-HTTP URL, '
        'skipping cache: $videoUrl',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
      );
      return;
    }

    // Skip if already queued
    if (_cacheQueue.any((r) => r.videoId == video.id)) return;

    _cacheQueue.add(
      _CacheRequest(
        videoId: video.id,
        videoUrl: videoUrl,
        sha256: video.sha256,
      ),
    );

    // Process queue if under concurrency limit
    unawaited(_processCacheQueue());
  }

  /// Processes the background cache download queue, one at a time.
  ///
  /// This prevents multiple simultaneous downloads from saturating bandwidth
  /// and causing jittery playback on the foreground video.
  Future<void> _processCacheQueue() async {
    if (_activeCacheDownloads >= _maxConcurrentCacheDownloads) return;
    if (_cacheQueue.isEmpty) return;
    if (isClosed) return;

    _activeCacheDownloads++;
    final request = _cacheQueue.removeFirst();

    try {
      final cache = _mediaCache;
      if (cache == null) return;

      // Re-check cache (may have been cached while queued)
      if (cache.getCachedFileSync(request.videoId) != null) {
        return;
      }

      Log.debug(
        'FullscreenFeedBloc: Background caching video ${request.videoId}',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
      );

      // Get auth headers if needed (for authenticated Blossom content)
      Map<String, String>? authHeaders;
      final blossomAuth = _blossomAuthService;
      final sha256 = request.sha256;
      if (blossomAuth != null && sha256 != null) {
        // Extract the server origin from the video URL so the BUD-01 kind
        // 24242 auth event includes the optional `server` tag.  Without it,
        // media.divine.video returns 401 on bare-blob GET requests even when
        // the hash and signature are otherwise valid.
        final serverUrl = _serverOrigin(request.videoUrl);
        final header = await blossomAuth.createGetAuthHeader(
          sha256Hash: sha256,
          serverUrl: serverUrl,
        );
        if (header != null) {
          authHeaders = {'Authorization': header};
        }
      }

      await cache.downloadFile(
        request.videoUrl,
        key: request.videoId,
        authHeaders: authHeaders,
      );

      Log.debug(
        'FullscreenFeedBloc: Successfully cached video ${request.videoId}',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
      );
    } on Exception catch (error) {
      Log.error(
        'FullscreenFeedBloc: Failed to cache video '
        '${request.videoId}: $error',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
      );
    } finally {
      _activeCacheDownloads--;
      // Process next item in queue
      if (!isClosed) {
        unawaited(_processCacheQueue());
      }
    }
  }

  /// Handle a player-reported unavailable video.
  ///
  /// Confirms the asset really is missing via a HEAD request before
  /// permanently removing it. Transient player errors (network flake, slow
  /// TLS, etc.) must not trigger removal — only a hard 404 counts.
  ///
  /// Uses `sequential()` to serialize concurrent unavailable events so the
  /// dedupe set in [FullscreenFeedState.removedVideoIds] is authoritative
  /// even when multiple error callbacks race.
  Future<void> _onVideoUnavailable(
    FullscreenFeedVideoUnavailable event,
    Emitter<FullscreenFeedState> emit,
  ) async {
    final videoId = event.videoId;
    if (state.removedVideoIds.contains(videoId)) return;

    // Find the video in the current list (may have been pruned already).
    final index = state.videos.indexWhere((v) => v.id == videoId);
    if (index < 0) return;

    final videoUrl = state.videos[index].videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;

    final isMissing = await _availabilityChecker.isConfirmedMissing(videoUrl);
    if (!isMissing) {
      Log.warning(
        'FullscreenFeedBloc: Player reported notFound for $videoId but HEAD '
        'did not confirm 404 — treating as transient error, video stays.',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
      );
      return;
    }

    // Re-check dedupe in case another handler inserted the same id while
    // our HEAD was in flight.
    if (state.removedVideoIds.contains(videoId)) return;

    _onRemoveVideo?.call(videoId);

    final updatedRemoved = {...state.removedVideoIds, videoId};
    final nextIndex = index + 1;

    emit(
      state.copyWith(
        removedVideoIds: updatedRemoved,
        pendingSkipTarget: nextIndex,
      ),
    );
  }

  /// Handle UI acknowledgement of a pending skip signal.
  void _onSkipAcknowledged(
    FullscreenFeedSkipAcknowledged event,
    Emitter<FullscreenFeedState> emit,
  ) {
    if (state.pendingSkipTarget == null) return;
    emit(state.copyWith(clearPendingSkipTarget: true));
  }

  /// Handle a user-initiated removal (deletion, block, mute).
  ///
  /// Removes the video from [FullscreenFeedState.videos] directly because
  /// the upstream source may not be alive to push an updated list — the
  /// launching widget often unmounts when the fullscreen route is pushed
  /// outside its shell. When the last video is removed, transitions the
  /// status to [FullscreenFeedStatus.emptyAfterRemoval] so the screen
  /// pops the route.
  ///
  /// Skips the HEAD-check that [_onVideoUnavailable] performs because the
  /// server has already confirmed the deletion (or the user explicitly
  /// asked to hide the content), so a transient-error fallback is wrong.
  void _onVideoRemoved(
    FullscreenFeedVideoRemoved event,
    Emitter<FullscreenFeedState> emit,
  ) {
    final videoId = event.videoId;
    if (state.removedVideoIds.contains(videoId)) return;

    final index = state.videos.indexWhere((v) => v.id == videoId);
    final updatedRemoved = {...state.removedVideoIds, videoId};

    if (index < 0) {
      // Not in the visible list — still record the dedupe so a later
      // pagination push can't re-introduce it.
      emit(state.copyWith(removedVideoIds: updatedRemoved));
      return;
    }

    final updatedVideos = [...state.videos]..removeAt(index);
    _onRemoveVideo?.call(videoId);

    if (updatedVideos.isEmpty) {
      emit(
        state.copyWith(
          status: FullscreenFeedStatus.emptyAfterRemoval,
          videos: const [],
          removedVideoIds: updatedRemoved,
          clearPendingSkipTarget: true,
        ),
      );
      return;
    }

    // Removing an item before the cursor shifts every later item down by
    // one. Without this shift the visible video would jump from cur to
    // cur+1 — for user-delete this never happens (the deleted item IS
    // the cursor), but the bus is the entry point for the upcoming
    // block / mute sweep where multi-video removals land at any index.
    final shifted = index < state.currentIndex
        ? state.currentIndex - 1
        : state.currentIndex;
    final clampedIndex = shifted.clamp(0, updatedVideos.length - 1);
    emit(
      state.copyWith(
        videos: updatedVideos,
        currentIndex: clampedIndex,
        removedVideoIds: updatedRemoved,
      ),
    );
  }

  /// Extracts the scheme+host origin from [url], e.g.
  /// `https://media.divine.video/abc123` → `https://media.divine.video`.
  ///
  /// Returns `null` when the URL cannot be parsed, so callers can fall back
  /// to omitting the `server` tag rather than sending a malformed value.
  static String? _serverOrigin(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || uri.host.isEmpty) return null;
      return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> close() async {
    await _hasMoreSubscription?.cancel();
    await _removedIdsSubscription?.cancel();
    _cacheQueue.clear();
    return super.close();
  }
}

/// A pending background cache download request.
class _CacheRequest {
  const _CacheRequest({
    required this.videoId,
    required this.videoUrl,
    this.sha256,
  });

  final String videoId;
  final String videoUrl;
  final String? sha256;
}
