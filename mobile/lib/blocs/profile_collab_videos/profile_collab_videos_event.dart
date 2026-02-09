// ABOUTME: Events for the ProfileCollabVideosBloc
// ABOUTME: Defines actions for fetching and paginating collab videos

part of 'profile_collab_videos_bloc.dart';

/// Base class for all profile collab videos events.
sealed class ProfileCollabVideosEvent {
  const ProfileCollabVideosEvent();
}

/// Request to fetch collab videos for the target user.
///
/// This triggers:
/// 1. Funnelcake REST API call (primary)
/// 2. Nostr relay p-tag query (fallback)
/// 3. Client-side filtering to confirm collaborator status
final class ProfileCollabVideosFetchRequested extends ProfileCollabVideosEvent {
  const ProfileCollabVideosFetchRequested();
}

/// Request to load more collab videos (pagination).
///
/// Uses [until] cursor from the last video's createdAt timestamp.
/// Only effective after initial fetch has completed.
final class ProfileCollabVideosLoadMoreRequested
    extends ProfileCollabVideosEvent {
  const ProfileCollabVideosLoadMoreRequested();
}
