// ABOUTME: Events for the ProfileRepostedVideosBloc
// ABOUTME: Defines actions for syncing and refreshing reposted videos

part of 'profile_reposted_videos_bloc.dart';

/// Base class for all profile reposted videos events
sealed class ProfileRepostedVideosEvent {
  const ProfileRepostedVideosEvent();
}

/// Request to sync repost records from repository and load videos.
///
/// This triggers:
/// 1. Sync of repost records from RepostsRepository
/// 2. Resolution of addressable IDs to VideoEvents
final class ProfileRepostedVideosSyncRequested
    extends ProfileRepostedVideosEvent {
  const ProfileRepostedVideosSyncRequested();
}

/// Request to start listening for repost changes from the repository.
///
/// This should be dispatched once when the screen/widget is initialized.
/// Uses emit.forEach internally to reactively update state when reposts change.
final class ProfileRepostedVideosSubscriptionRequested
    extends ProfileRepostedVideosEvent {
  const ProfileRepostedVideosSubscriptionRequested();
}

/// Request to load more reposted videos (pagination).
///
/// Fetches the next batch of videos from the existing repost records list.
/// Only effective after initial sync has completed.
final class ProfileRepostedVideosLoadMoreRequested
    extends ProfileRepostedVideosEvent {
  const ProfileRepostedVideosLoadMoreRequested();
}
