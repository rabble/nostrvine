// ABOUTME: Provider for managing following list state
// ABOUTME: Handles current user (from FollowRepository) and other users (from Nostr)

import 'dart:async';

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'following_list_provider.g.dart';

/// Provider for fetching and managing a user's following list
/// - For current user: uses FollowRepository (reactive updates)
/// - For other users: fetches from Nostr relays
@riverpod
class FollowingListNotifier extends _$FollowingListNotifier {
  StreamSubscription<Event>? _subscription;
  FollowRepository? _repository;

  @override
  Future<List<String>> build(String pubkey) async {
    // Clean up subscription on dispose
    ref.onDispose(() {
      _subscription?.cancel();
    });

    final authService = ref.read(authServiceProvider);
    final isCurrentUser = pubkey == authService.currentPublicKeyHex;

    if (isCurrentUser) {
      // Inject repository for current user operations
      final repository = ref.watch(followRepositoryProvider);
      if (repository == null) {
        // Not authenticated - return empty list
        return [];
      }
      _repository = repository;
      return _loadCurrentUserFollowing();
    } else {
      return _loadOtherUserFollowing(pubkey);
    }
  }

  /// Load current user's following from FollowRepository
  Future<List<String>> _loadCurrentUserFollowing() async {
    final repository = _repository!;

    // Listen for changes via stream to rebuild when following list changes
    final subscription = repository.followingStream.listen((followingList) {
      state = AsyncData(followingList);
    });

    ref.onDispose(() {
      subscription.cancel();
    });

    return repository.followingPubkeys;
  }

  /// Load other user's following from Nostr relays
  Future<List<String>> _loadOtherUserFollowing(String pubkey) async {
    final nostrService = ref.read(nostrServiceProvider);
    final completer = Completer<List<String>>();

    // Subscribe to the user's kind 3 contact list events
    final eventStream = nostrService.subscribe([
      Filter(
        authors: [pubkey],
        kinds: const [3], // Contact lists
        limit: 1, // Get most recent only
      ),
    ]);

    // Apply timeout
    final timeoutStream = eventStream.timeout(
      const Duration(seconds: 5),
      onTimeout: (sink) {
        if (!completer.isCompleted) {
          // Return empty list on timeout if no data received
          completer.complete([]);
        }
        sink.close();
      },
    );

    _subscription = timeoutStream.listen(
      (event) {
        // Extract followed pubkeys from 'p' tags
        final following = <String>[];
        for (final tag in event.tags) {
          if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
            final followedPubkey = tag[1];
            if (!following.contains(followedPubkey)) {
              following.add(followedPubkey);
            }
          }
        }

        if (!completer.isCompleted) {
          completer.complete(following);
        }
      },
      onError: (error) {
        Log.error(
          'Error fetching following list: $error',
          name: 'FollowingListProvider',
          category: LogCategory.relay,
        );
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      },
    );

    return completer.future;
  }

  /// Refresh the following list
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(pubkey));
  }
}

/// Stream provider for current user's following list (reactive)
/// Use this when you only need the current user's following
@riverpod
Stream<List<String>> currentUserFollowingList(Ref ref) async* {
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
