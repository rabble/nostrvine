// ABOUTME: Provider for managing follow state and operations
// ABOUTME: Uses FollowRepository as source of truth, tracks in-progress operations

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'follow_state_provider.g.dart';

/// Stream provider for current user's following list (reactive)
@Riverpod(keepAlive: true)
Stream<List<String>> followingList(Ref ref) async* {
  final repository = ref.watch(followRepositoryProvider);
  if (repository == null) {
    // Not authenticated - emit empty list
    yield [];
    return;
  }

  // Emit current state immediately
  yield repository.followingPubkeys;

  // Yield updates from repository stream
  yield* repository.followingStream;
}

/// Family provider to check if current user is following a specific pubkey
/// This is reactive - listens to repository's followingStream for updates
@riverpod
Stream<bool> isFollowing(Ref ref, String pubkey) async* {
  final repository = ref.watch(followRepositoryProvider);
  if (repository == null) {
    // Not authenticated - emit false (not following)
    yield false;
    return;
  }

  // Emit current state immediately
  yield repository.isFollowing(pubkey);

  // Yield updates when following list changes
  await for (final followingList in repository.followingStream) {
    yield followingList.contains(pubkey);
  }
}

/// Notifier for managing follow state and operations
/// - Checks if current user is following a pubkey
/// - Tracks which pubkeys have active follow/unfollow operations
/// - Provides follow/unfollow/toggle actions
///
/// Returns empty set and no-ops when not authenticated.
@Riverpod(keepAlive: true)
class FollowOperations extends _$FollowOperations {
  @override
  Set<String> build() {
    // Watch repository to rebuild when it becomes available
    ref.watch(followRepositoryProvider);
    // Return empty set - this tracks in-progress operations only
    return {};
  }

  /// Get the current repository (reads fresh value each time)
  FollowRepository? get _repository => ref.read(followRepositoryProvider);

  /// Check if a follow operation is in progress for a pubkey
  bool isInProgress(String pubkey) => state.contains(pubkey);

  /// Follow a user via FollowRepository
  Future<void> follow(String pubkey) async {
    final repository = _repository;
    if (repository == null || state.contains(pubkey)) return;

    // Mark operation as in progress
    state = {...state, pubkey};

    try {
      await repository.follow(pubkey);

      Log.info(
        'Followed user via repository: $pubkey',
        name: 'FollowOperations',
        category: LogCategory.system,
      );
    } finally {
      // Remove from in-progress set
      state = {...state}..remove(pubkey);
    }
  }

  /// Unfollow a user via FollowRepository
  Future<void> unfollow(String pubkey) async {
    final repository = _repository;
    if (repository == null || state.contains(pubkey)) return;

    // Mark operation as in progress
    state = {...state, pubkey};

    try {
      await repository.unfollow(pubkey);

      Log.info(
        'Unfollowed user via repository: $pubkey',
        name: 'FollowOperations',
        category: LogCategory.system,
      );
    } finally {
      // Remove from in-progress set
      state = {...state}..remove(pubkey);
    }
  }

  /// Toggle follow state for a user
  Future<void> toggle(String pubkey) async {
    final repository = _repository;
    if (repository == null) return;

    if (repository.isFollowing(pubkey)) {
      await unfollow(pubkey);
    } else {
      await follow(pubkey);
    }
  }
}
