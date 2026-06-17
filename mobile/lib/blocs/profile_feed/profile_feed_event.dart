part of 'profile_feed_cubit.dart';

/// Base class for [ProfileFeedCubit] events.
sealed class ProfileFeedEvent extends Equatable {
  const ProfileFeedEvent();

  @override
  List<Object?> get props => [];
}

/// Kicks off the cold load (relay snapshot + REST composition). Dispatched once
/// from the constructor.
final class ProfileFeedStarted extends ProfileFeedEvent {
  const ProfileFeedStarted();
}

/// Loads the next page (REST offset page or Nostr-fallback page). `droppable`.
final class ProfileFeedLoadMoreRequested extends ProfileFeedEvent {
  const ProfileFeedLoadMoreRequested();
}

/// Forces a full refresh. `restartable` — the latest refresh wins.
final class ProfileFeedRefreshRequested extends ProfileFeedEvent {
  const ProfileFeedRefreshRequested();
}

/// Re-applies feed filters in place over the cached source (no re-fetch).
/// Dispatched when a blocklist/content-preference version changes (#4782).
final class ProfileFeedFiltersChanged extends ProfileFeedEvent {
  const ProfileFeedFiltersChanged();
}

/// Internal: the VideoEventService relay snapshot changed (via `addListener`).
/// This is the sole realtime add path — new videos for the author flow through
/// here too, since the service always notifies listeners when a video lands.
final class ProfileFeedRelaySnapshotChanged extends ProfileFeedEvent {
  const ProfileFeedRelaySnapshotChanged();
}

/// Internal: a video by this author was updated; collapses to a refresh.
/// `restartable`.
final class ProfileFeedVideoUpdated extends ProfileFeedEvent {
  const ProfileFeedVideoUpdated();
}

/// Internal: the cold-load hard timeout fired; clears [ProfileFeedState.isInitialLoad].
final class ProfileFeedInitialLoadTimedOut extends ProfileFeedEvent {
  const ProfileFeedInitialLoadTimedOut();
}

/// Internal: background Nostr enrichment of the REST page completed; merge the
/// enriched copies back over their source keys (#3705).
final class ProfileFeedEnrichmentReady extends ProfileFeedEvent {
  const ProfileFeedEnrichmentReady({
    required this.enriched,
    required this.sourceKeys,
  });

  final List<VideoEvent> enriched;
  final Set<String> sourceKeys;

  @override
  List<Object?> get props => [enriched, sourceKeys];
}
