// ABOUTME: Provider for managing following list state
// ABOUTME: Handles current user (from SocialRepository) and other users (from Nostr)

import 'dart:async';

import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'following_list_provider.g.dart';

/// Provider for fetching and managing a user's following list
/// - For current user: uses SocialRepository (reactive updates)
/// - For other users: fetches from Nostr relays
@riverpod
class FollowingListNotifier extends _$FollowingListNotifier {
  StreamSubscription<nostr_sdk.Event>? _subscription;

  @override
  Future<List<String>> build(String pubkey) async {
    // Clean up subscription on dispose
    ref.onDispose(() {
      _subscription?.cancel();
    });

    final authService = ref.read(authServiceProvider);
    final isCurrentUser = pubkey == authService.currentPublicKeyHex;

    if (isCurrentUser) {
      return _loadCurrentUserFollowing();
    } else {
      return _loadOtherUserFollowing(pubkey);
    }
  }

  /// Load current user's following from SocialRepository
  Future<List<String>> _loadCurrentUserFollowing() async {
    final repository = ref.watch(socialRepositoryProvider);

    // Listen for changes to rebuild when following list changes
    void listener() {
      // Update state when repository changes
      state = AsyncData(repository.followingPubkeys);
    }

    repository.addListener(listener);
    ref.onDispose(() {
      repository.removeListener(listener);
    });

    return repository.followingPubkeys;
  }

  /// Load other user's following from Nostr relays
  Future<List<String>> _loadOtherUserFollowing(String pubkey) async {
    final nostrService = ref.read(nostrServiceProvider);
    final completer = Completer<List<String>>();

    // Subscribe to the user's kind 3 contact list events
    final eventStream = nostrService.subscribeToEvents(
      filters: [
        nostr_sdk.Filter(
          authors: [pubkey],
          kinds: [3], // Contact lists
          limit: 1, // Get most recent only
        ),
      ],
    );

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
  final repository = ref.watch(socialRepositoryProvider);

  // Emit current state immediately
  yield repository.followingPubkeys;

  // Create a stream controller to emit updates when repository changes
  final controller = StreamController<List<String>>();

  void listener() {
    if (!controller.isClosed) {
      controller.add(repository.followingPubkeys);
    }
  }

  repository.addListener(listener);
  ref.onDispose(() {
    repository.removeListener(listener);
    controller.close();
  });

  yield* controller.stream;
}

/// Simple provider to check if currently following a specific pubkey
/// Uses the SocialRepository as source of truth
@riverpod
bool isFollowingUser(Ref ref, String pubkey) {
  final repository = ref.watch(socialRepositoryProvider);

  // Listen for changes to rebuild when following state changes
  void listener() {
    ref.invalidateSelf();
  }

  repository.addListener(listener);
  ref.onDispose(() {
    repository.removeListener(listener);
  });

  return repository.isFollowing(pubkey);
}

