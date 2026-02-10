// ABOUTME: Events for FullscreenFeedBloc
// ABOUTME: Handles video list updates, pagination, and index changes

part of 'fullscreen_feed_bloc.dart';

/// Base class for all fullscreen feed events.
sealed class FullscreenFeedEvent extends Equatable {
  const FullscreenFeedEvent();
}

/// Start listening to the videos stream.
///
/// Dispatched when the fullscreen feed initializes.
final class FullscreenFeedStarted extends FullscreenFeedEvent {
  const FullscreenFeedStarted();

  @override
  List<Object?> get props => [];
}

/// Request to load more videos.
///
/// Triggers the onLoadMore callback provided by the source.
final class FullscreenFeedLoadMoreRequested extends FullscreenFeedEvent {
  const FullscreenFeedLoadMoreRequested();

  @override
  List<Object?> get props => [];
}

/// Current video index changed (user swiped).
final class FullscreenFeedIndexChanged extends FullscreenFeedEvent {
  const FullscreenFeedIndexChanged(this.index);

  /// The new current index.
  final int index;

  @override
  List<Object?> get props => [index];
}

/// Dispatched when a video is ready for playback.
///
/// BLoC triggers background caching for uncached videos.
final class FullscreenFeedVideoCacheStarted extends FullscreenFeedEvent {
  const FullscreenFeedVideoCacheStarted({required this.index});

  /// Index of the video that is ready.
  final int index;

  @override
  List<Object?> get props => [index];
}

/// Dispatched periodically with position updates from the video player.
///
/// BLoC checks for loop enforcement (seek to zero at max duration).
final class FullscreenFeedPositionUpdated extends FullscreenFeedEvent {
  const FullscreenFeedPositionUpdated({
    required this.index,
    required this.position,
  });

  /// Index of the video being played.
  final int index;

  /// Current playback position.
  final Duration position;

  @override
  List<Object?> get props => [index, position];
}

/// Dispatched after widget executes a seek command.
///
/// Clears the seek command from state.
final class FullscreenFeedSeekCommandHandled extends FullscreenFeedEvent {
  const FullscreenFeedSeekCommandHandled();

  @override
  List<Object?> get props => [];
}
