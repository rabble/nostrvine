// ABOUTME: BLoC for fullscreen video feed playback
// ABOUTME: Receives video stream from source, manages playback index and pagination

import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/utils/unified_logger.dart';

part 'fullscreen_feed_event.dart';
part 'fullscreen_feed_state.dart';

/// BLoC for managing fullscreen video feed playback.
///
/// This BLoC acts as a bridge between various video sources (profile feed,
/// liked videos, reposts, etc.) and the fullscreen video player UI.
///
/// It receives:
/// - A [Stream] of videos from the source (for reactive updates)
/// - An optional [onLoadMore] callback to trigger pagination on the source
/// - An [initialIndex] for starting playback position
///
/// The source BLoC/provider remains the single source of truth for the video
/// list. This BLoC only manages fullscreen-specific state (current index,
/// loading indicators).
class FullscreenFeedBloc
    extends Bloc<FullscreenFeedEvent, FullscreenFeedState> {
  FullscreenFeedBloc({
    required Stream<List<VideoEvent>> videosStream,
    required int initialIndex,
    VoidCallback? onLoadMore,
  }) : _videosStream = videosStream,
       _onLoadMore = onLoadMore,
       super(FullscreenFeedState(currentIndex: initialIndex)) {
    on<FullscreenFeedStarted>(_onStarted);
    on<FullscreenFeedVideosUpdated>(_onVideosUpdated);
    on<FullscreenFeedLoadMoreRequested>(_onLoadMoreRequested);
    on<FullscreenFeedIndexChanged>(_onIndexChanged);
  }

  final Stream<List<VideoEvent>> _videosStream;
  final VoidCallback? _onLoadMore;
  StreamSubscription<List<VideoEvent>>? _videosSubscription;

  /// Handle feed started - subscribe to the videos stream.
  Future<void> _onStarted(
    FullscreenFeedStarted event,
    Emitter<FullscreenFeedState> emit,
  ) async {
    await _videosSubscription?.cancel();

    _videosSubscription = _videosStream.listen(
      (videos) => add(FullscreenFeedVideosUpdated(videos)),
      onError: (Object error) {
        Log.error(
          'FullscreenFeedBloc: Stream error - $error',
          name: 'FullscreenFeedBloc',
          category: LogCategory.video,
        );
        // Don't emit failure state here - keep showing existing videos
      },
    );
  }

  /// Handle videos updated from the source stream.
  void _onVideosUpdated(
    FullscreenFeedVideosUpdated event,
    Emitter<FullscreenFeedState> emit,
  ) {
    final videos = event.videos;

    Log.debug(
      'FullscreenFeedBloc: Videos updated, count=${videos.length}',
      name: 'FullscreenFeedBloc',
      category: LogCategory.video,
    );

    // Clamp current index to valid range
    final clampedIndex = videos.isEmpty
        ? 0
        : state.currentIndex.clamp(0, videos.length - 1);

    emit(
      state.copyWith(
        status: FullscreenFeedStatus.ready,
        videos: videos,
        currentIndex: clampedIndex,
        isLoadingMore: false,
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

  @override
  Future<void> close() {
    _videosSubscription?.cancel();
    return super.close();
  }
}
