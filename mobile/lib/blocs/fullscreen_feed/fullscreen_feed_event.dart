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

/// Source pagination availability changed.
final class FullscreenFeedHasMoreChanged extends FullscreenFeedEvent {
  const FullscreenFeedHasMoreChanged(this.hasMore);

  final bool hasMore;

  @override
  List<Object?> get props => [hasMore];
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

/// Dispatched when a video appears to be unavailable (player reported
/// [PlaybackStatus.notFound], web HEAD 404, etc.).
///
/// The BLoC confirms the failure with a HEAD request via the injected
/// [MediaAvailabilityChecker] before permanently removing the video. If
/// the asset actually responds 2xx/5xx/network-error, the event is treated
/// as a transient player failure and the video stays in place.
///
/// Dedupe is owned by the BLoC — repeated dispatches for the same
/// [videoId] are no-ops after the first confirmed removal.
final class FullscreenFeedVideoUnavailable extends FullscreenFeedEvent {
  const FullscreenFeedVideoUnavailable(this.videoId);

  /// Event ID of the video the player couldn't load.
  final String videoId;

  @override
  List<Object?> get props => [videoId];
}

/// Dispatched by the UI after it has consumed a pending skip signal emitted
/// by the BLoC (e.g. called `animateToPage`). Clears
/// [FullscreenFeedState.pendingSkipTarget] so a subsequent removal can
/// produce a new skip without being deduped by value-equality.
final class FullscreenFeedSkipAcknowledged extends FullscreenFeedEvent {
  const FullscreenFeedSkipAcknowledged();

  @override
  List<Object?> get props => [];
}

/// Dispatched when a video must be removed from the feed immediately,
/// without any availability check — user-initiated deletion (and, soon,
/// block / mute) propagates through this event.
///
/// Shares the removal tail with [FullscreenFeedVideoUnavailable]: the
/// id is added to [FullscreenFeedState.removedVideoIds], the video is
/// dropped from [FullscreenFeedState.videos], and the current index is
/// clamped. When the last video is removed the BLoC transitions to
/// [FullscreenFeedStatus.emptyAfterRemoval] so the screen can pop.
///
/// Dedupe is owned by the BLoC — repeated dispatches for the same
/// [videoId] are no-ops after the first removal.
final class FullscreenFeedVideoRemoved extends FullscreenFeedEvent {
  const FullscreenFeedVideoRemoved(this.videoId);

  /// Event ID of the video to remove.
  final String videoId;

  @override
  List<Object?> get props => [videoId];
}
