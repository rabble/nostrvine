// ABOUTME: Provider for managing follow state and operations
// ABOUTME: Uses SocialRepository as source of truth, tracks in-progress operations

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'follow_state_provider.g.dart';

/// Notifier for managing follow state and operations
/// - Checks if current user is following a pubkey
/// - Tracks which pubkeys have active follow/unfollow operations
/// - Provides follow/unfollow/toggle actions
@Riverpod(keepAlive: true)
class FollowOperations extends _$FollowOperations {
  @override
  Set<String> build() => {};

  /// Check if current user is following a specific pubkey
  bool isFollowing(String pubkey) {
    final repository = ref.read(socialRepositoryProvider);
    return repository.isFollowing(pubkey);
  }

  /// Check if a follow operation is in progress for a pubkey
  bool isInProgress(String pubkey) => state.contains(pubkey);

  /// Follow a user via SocialRepository
  Future<void> follow(String pubkey) async {
    if (state.contains(pubkey)) return;

    // Mark operation as in progress
    state = {...state, pubkey};

    try {
      final repository = ref.read(socialRepositoryProvider);
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

  /// Unfollow a user via SocialRepository
  Future<void> unfollow(String pubkey) async {
    if (state.contains(pubkey)) return;

    // Mark operation as in progress
    state = {...state, pubkey};

    try {
      final repository = ref.read(socialRepositoryProvider);
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
    final repository = ref.read(socialRepositoryProvider);
    if (repository.isFollowing(pubkey)) {
      await unfollow(pubkey);
    } else {
      await follow(pubkey);
    }
  }
}
