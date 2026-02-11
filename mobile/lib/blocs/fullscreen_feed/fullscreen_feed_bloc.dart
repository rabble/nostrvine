// ABOUTME: BLoC for fullscreen video feed playback
// ABOUTME: Receives video stream from source, manages playback index and pagination
// ABOUTME: Handles cache resolution, background caching, and loop enforcement

import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_cache/media_cache.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

part 'fullscreen_feed_event.dart';
part 'fullscreen_feed_state.dart';

/// Factory function for creating a [VideoFeedController].
///
/// Used for dependency injection in tests.
typedef VideoFeedControllerFactory =
    VideoFeedController Function(List<VideoItem> videos, int initialIndex);

/// Maximum playback duration before looping back to start.
///
/// TODO(product): Confirm with product - original Vine was 6.0s exactly.
/// Current app uses 6.3s without clear documentation.
const maxPlaybackDuration = Duration(seconds: 6);

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
/// loading indicators, seek commands).
///
/// **Playback hooks integration:**
/// - Videos are cache-resolved when received (cached file paths replace URLs)
/// - Background caching triggered via [FullscreenFeedVideoCacheStarted]
/// - Loop enforcement via [FullscreenFeedPositionUpdated] → [SeekCommand]
class FullscreenFeedBloc
    extends Bloc<FullscreenFeedEvent, FullscreenFeedState> {
  FullscreenFeedBloc({
    required int initialIndex,
    required MediaCacheManager mediaCache,
    PlayerPool? playerPool,
    VoidCallback? onLoadMore,
    BlossomAuthService? blossomAuthService,
    Stream<List<VideoEvent>> videosStream = const Stream.empty(),
    @visibleForTesting VideoFeedControllerFactory? controllerFactory,
  }) : _videosStream = videosStream,
       _mediaCache = mediaCache,
       _playerPool = playerPool,
       _onLoadMore = onLoadMore,
       _blossomAuthService = blossomAuthService,
       _controllerFactory = controllerFactory,
       super(FullscreenFeedState(currentIndex: initialIndex)) {
    on<FullscreenFeedStarted>(_onStarted);
    on<FullscreenFeedVideosUpdated>(_onVideosUpdated);
    on<FullscreenFeedLoadMoreRequested>(_onLoadMoreRequested);
    on<FullscreenFeedIndexChanged>(_onIndexChanged);
    on<FullscreenFeedVideoCacheStarted>(_onVideoCacheStarted);
    on<FullscreenFeedPositionUpdated>(_onPositionUpdated);
    on<FullscreenFeedSeekCommandHandled>(_onSeekCommandHandled);
    on<FullscreenFeedActiveChanged>(_onActiveChanged);
  }

  final Stream<List<VideoEvent>> _videosStream;
  final VoidCallback? _onLoadMore;
  final MediaCacheManager _mediaCache;
  final BlossomAuthService? _blossomAuthService;
  final PlayerPool? _playerPool;
  final VideoFeedControllerFactory? _controllerFactory;

  /// Whether this BLoC is configured to manage a [VideoFeedController].
  bool get _canManageController {
    return _playerPool != null || _controllerFactory != null;
  }

  /// Handle feed started - subscribe to the videos stream using emit.forEach.
  ///
  /// emit.forEach automatically:
  /// - Subscribes to the stream
  /// - Emits states for each data event
  /// - Cancels the subscription when the bloc is closed
  ///
  /// Videos are cache-resolved when received - if a video's file is cached,
  /// the videoUrl is replaced with the cached file path for instant playback.
  Future<void> _onStarted(
    FullscreenFeedStarted event,
    Emitter<FullscreenFeedState> emit,
  ) async {
    await emit.forEach<List<VideoEvent>>(
      _videosStream,
      onData: (videos) {
        Log.debug(
          'FullscreenFeedBloc: Videos updated, count=${videos.length}',
          name: 'FullscreenFeedBloc',
          category: LogCategory.video,
        );

        // Resolve cache paths for videos
        final resolvedVideos = _resolveCachePaths(videos);

        // Clamp current index to valid range
        final clampedIndex = resolvedVideos.isEmpty
            ? 0
            : state.currentIndex.clamp(0, resolvedVideos.length - 1);

        final newState = state.copyWith(
          status: FullscreenFeedStatus.ready,
          videos: resolvedVideos,
          currentIndex: clampedIndex,
          isLoadingMore: false,
        );

        return _updateController(newState);
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

  /// Handle videos updated from an external source.
  ///
  /// Resolves cache paths and emits the updated video list, same as
  /// [_onStarted]'s `onData` but triggered via a discrete event.
  void _onVideosUpdated(
    FullscreenFeedVideosUpdated event,
    Emitter<FullscreenFeedState> emit,
  ) {
    Log.debug(
      'FullscreenFeedBloc: Videos updated, count=${event.videos.length}',
      name: 'FullscreenFeedBloc',
      category: LogCategory.video,
    );

    final resolvedVideos = _resolveCachePaths(event.videos);

    final clampedIndex = resolvedVideos.isEmpty
        ? 0
        : state.currentIndex.clamp(0, resolvedVideos.length - 1);

    final newState = state.copyWith(
      status: FullscreenFeedStatus.ready,
      videos: resolvedVideos,
      currentIndex: clampedIndex,
      isLoadingMore: false,
    );

    emit(_updateController(newState));
  }

  /// Resolves cache paths for a list of videos.
  ///
  /// For each video, checks if a cached file exists and replaces the videoUrl
  /// with the cached file path for instant playback.
  List<VideoEvent> _resolveCachePaths(List<VideoEvent> videos) {
    return videos.map((video) {
      final cachedFile = _mediaCache.getCachedFileSync(video.id);
      if (cachedFile == null) return video;

      Log.debug(
        'FullscreenFeedBloc: Cache hit for video ${video.id}',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
      );

      return video.copyWith(videoUrl: cachedFile.path);
    }).toList();
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
    onLoadMore();
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

  /// Handle video ready for caching - trigger background caching.
  ///
  /// Called when the video player signals a video is ready for playback.
  /// If the video is not already cached, downloads it in the background
  /// for future instant playback.
  Future<void> _onVideoCacheStarted(
    FullscreenFeedVideoCacheStarted event,
    Emitter<FullscreenFeedState> emit,
  ) async {
    if (event.index < 0 || event.index >= state.videos.length) return;

    final video = state.videos[event.index];

    // Skip if already cached
    if (_mediaCache.getCachedFileSync(video.id) != null) {
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

    Log.debug(
      'FullscreenFeedBloc: Background caching video ${video.id}',
      name: 'FullscreenFeedBloc',
      category: LogCategory.video,
    );

    // Get auth headers if needed (for authenticated Blossom content)
    Map<String, String>? authHeaders;
    final blossomAuth = _blossomAuthService;
    final sha256 = video.sha256;
    if (blossomAuth != null && sha256 != null) {
      final header = await blossomAuth.createGetAuthHeader(sha256Hash: sha256);
      if (header != null) {
        authHeaders = {'Authorization': header};
      }
    }

    // Cache in background (fire and forget)

    try {
      unawaited(
        _mediaCache.downloadFile(
          videoUrl,
          key: video.id,
          authHeaders: authHeaders,
        ),
      );

      Log.debug(
        'FullscreenFeedBloc: Successfully cached video ${video.id}',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
      );
    } catch (error) {
      Log.error(
        'FullscreenFeedBloc: Failed to cache video ${video.id}: $error',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
      );
    }
  }

  /// Handle position update - check for loop enforcement.
  ///
  /// When the playback position exceeds [maxPlaybackDuration], seeks back to
  /// zero. If the BLoC manages the controller, seeks directly. Otherwise emits
  /// a [SeekCommand] for the widget to execute.
  void _onPositionUpdated(
    FullscreenFeedPositionUpdated event,
    Emitter<FullscreenFeedState> emit,
  ) {
    if (event.position >= maxPlaybackDuration) {
      Log.debug(
        'FullscreenFeedBloc: Loop enforcement at '
        '${event.position.inMilliseconds}ms',
        name: 'FullscreenFeedBloc',
        category: LogCategory.video,
      );

      final controller = state.controller;

      if (controller == null) {
        return emit(
          state.copyWith(
            seekCommand: SeekCommand(
              index: event.index,
              position: Duration.zero,
            ),
          ),
        );
      }

      controller.seek(Duration.zero);
    }
  }

  /// Handle seek command handled - clear the seek command from state.
  void _onSeekCommandHandled(
    FullscreenFeedSeekCommandHandled event,
    Emitter<FullscreenFeedState> emit,
  ) {
    emit(state.copyWith(clearSeekCommand: true));
  }

  /// Handle active state change (e.g. overlay visibility).
  void _onActiveChanged(
    FullscreenFeedActiveChanged event,
    Emitter<FullscreenFeedState> emit,
  ) {
    state.controller?.setActive(active: event.isActive);
  }

  /// Initializes the managed controller or updates it with new videos.
  ///
  /// Returns [newState] with controller and lastPooledVideos set.
  /// No-op (returns [newState] unchanged) when the BLoC is not configured to
  /// manage a controller.
  FullscreenFeedState _updateController(FullscreenFeedState newState) {
    if (!_canManageController) return newState;

    if (newState.controller == null && newState.hasPooledVideos) {
      final controller = _createManagedController(
        newState.pooledVideos,
        newState.currentIndex,
      );
      return newState.copyWith(
        controller: controller,
        lastPooledVideos: newState.pooledVideos,
      );
    }

    final controller = newState.controller;
    final lastVideos = newState.lastPooledVideos;
    if (controller == null || lastVideos == null) return newState;

    final addedVideos = newState.pooledVideos
        .where((v) => !lastVideos.any((old) => old.id == v.id))
        .toList();

    if (addedVideos.isNotEmpty) {
      controller.addVideos(addedVideos);
    }

    return newState.copyWith(lastPooledVideos: newState.pooledVideos);
  }

  /// Creates a [VideoFeedController] owned by this BLoC.
  ///
  /// Uses [_controllerFactory] if provided (for testing), otherwise creates
  /// a controller with [_playerPool] and hooks wired to dispatch events.
  VideoFeedController _createManagedController(
    List<VideoItem> videos,
    int initialIndex,
  ) {
    final controllerFactory = _controllerFactory;
    if (controllerFactory != null) {
      return controllerFactory(videos, initialIndex);
    }

    return VideoFeedController(
      videos: videos,
      pool: _playerPool!,
      initialIndex: initialIndex,
      onVideoReady: (index, player) {
        if (isClosed) return;
        add(FullscreenFeedVideoCacheStarted(index: index));
      },
      positionCallback: (index, position) {
        if (isClosed) return;
        add(FullscreenFeedPositionUpdated(index: index, position: position));
      },
      positionCallbackInterval: const Duration(milliseconds: 100),
    );
  }

  @override
  Future<void> close() {
    state.controller?.dispose();
    return super.close();
  }
}
