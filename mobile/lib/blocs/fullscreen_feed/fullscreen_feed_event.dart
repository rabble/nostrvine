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
