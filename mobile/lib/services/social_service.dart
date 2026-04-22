// ABOUTME: Social interaction service for right-to-be-forgotten and stats
// ABOUTME: Note: NIP-02 contact list (follow/unfollow) is handled by FollowRepository
// ABOUTME: Note: Follower count stats are handled by FollowRepository
// ABOUTME: Note: NIP-18 reposts are handled by RepostsRepository
// ABOUTME: Note: NIP-51 kind 30000 people lists are handled by PeopleListsRepository

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for right-to-be-forgotten publishing and profile video-count
/// statistics. NIP-51 kind 30000 people lists now live in
/// `PeopleListsRepository` — removed from this service in Task 13.
class SocialService {
  SocialService(this._nostrService, this._authService);

  final NostrClient _nostrService;
  final AuthService _authService;

  // === PROFILE STATISTICS ===

  /// Get video count for a specific user
  Future<int> getUserVideoCount(String pubkey) async {
    Log.debug(
      '📱 Fetching video count for: $pubkey',
      name: 'SocialService',
      category: LogCategory.system,
    );

    try {
      final completer = Completer<int>();
      var videoCount = 0;

      // Subscribe to user's video events using NIP-71 compliant kinds
      final subscription = _nostrService.subscribe([
        Filter(
          authors: [pubkey],
          kinds:
              NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video kinds: 22, 21, 34236, 34235
        ),
      ]);

      subscription.listen(
        (event) {
          videoCount++;
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(videoCount);
          }
        },
        onError: (error) {
          Log.error(
            'Error fetching video count: $error',
            name: 'SocialService',
            category: LogCategory.system,
          );
          if (!completer.isCompleted) {
            completer.complete(0);
          }
        },
      );

      final result = await completer.future;
      Log.debug(
        '📱 Video count fetched: $result',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return result;
    } catch (e) {
      Log.error(
        'Error fetching video count: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return 0;
    }
  }

  // === ACCOUNT MANAGEMENT ===

  /// Publishes a NIP-62 "right to be forgotten" deletion request event
  Future<void> publishRightToBeForgotten() async {
    if (!_authService.isAuthenticated) {
      Log.error(
        'Cannot publish deletion request - user not authenticated',
        name: 'SocialService',
        category: LogCategory.system,
      );
      throw Exception('User not authenticated');
    }

    Log.debug(
      '📱️ Publishing NIP-62 right to be forgotten event...',
      name: 'SocialService',
      category: LogCategory.system,
    );

    try {
      // Create NIP-62 deletion request event (Kind 5 with special formatting)
      final event = await _authService.createAndSignEvent(
        kind: 5,
        content:
            'REQUEST: Delete all data associated with this pubkey under right to be forgotten',
        tags: [
          ['p', _authService.currentPublicKeyHex!], // Reference to own pubkey
          ['k', '0'], // Request deletion of Kind 0 (profile) events
          ['k', '1'], // Request deletion of Kind 1 (text note) events
          ['k', '3'], // Request deletion of Kind 3 (contact list) events
          ['k', '6'], // Request deletion of Kind 6 (repost) events
          ['k', '7'], // Request deletion of Kind 7 (reaction) events
          [
            'k',
            '${NIP71VideoKinds.addressableShortVideo}',
          ], // Request deletion of addressable short video events per NIP-71
        ],
      );

      if (event == null) {
        throw Exception('Failed to create deletion request event');
      }

      // Publish the deletion request
      final sentEvent = await _nostrService.publishEvent(event);

      if (sentEvent == null) {
        throw Exception('Failed to publish deletion request to relays');
      }

      Log.info(
        'NIP-62 deletion request published: ${event.id}',
        name: 'SocialService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error publishing deletion request: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  void dispose() {
    Log.debug(
      '📱️ Disposing SocialService',
      name: 'SocialService',
      category: LogCategory.system,
    );
  }
}
