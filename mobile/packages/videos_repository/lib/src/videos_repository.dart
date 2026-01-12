// ABOUTME: Repository for video operations with Nostr.
// ABOUTME: Provides video queries, counts, and real-time updates

import 'dart:async';
import 'dart:developer' as developer;

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';

/// NIP-71 video event kinds.
const _videoKinds = [34236, 34235];

/// Repository for video operations with Nostr.
class VideosRepository {
  /// Creates a new videos repository.
  ///
  /// Parameters:
  /// - [nostrClient]: Client for Nostr relay communication
  VideosRepository({required NostrClient nostrClient})
    : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

  /// Stream of the current user's video count.
  Stream<int> get myVideoCountStream => _myVideoCountSubject.stream;

  final _myVideoCountSubject = BehaviorSubject<int>.seeded(0);
  StreamSubscription<Event>? _myVideosSubscription;
  String? _subscriptionId;
  bool _isSubscribed = false;

  /// Initialize the repository and subscribe to own videos for real-time
  /// updates.
  Future<void> initialize() async {
    if (_isSubscribed) return;

    final myPubkey = _nostrClient.publicKey;
    if (myPubkey.isEmpty) {
      developer.log(
        'Cannot subscribe to my videos - no public key',
        name: 'VideosRepository',
      );
      return;
    }

    developer.log(
      'Subscribing to my videos for real-time count updates',
      name: 'VideosRepository',
    );

    _subscriptionId = 'my_videos_count_$myPubkey';
    final stream = _nostrClient.subscribe(
      [
        Filter(
          authors: [myPubkey],
          kinds: _videoKinds,
        ),
      ],
      subscriptionId: _subscriptionId,
    );

    final videoIds = <String>{};

    _myVideosSubscription = stream.listen(
      (event) {
        if (videoIds.add(event.id)) {
          _myVideoCountSubject.add(videoIds.length);
          developer.log(
            'Video event received, count: ${videoIds.length}',
            name: 'VideosRepository',
          );
        }
      },
      onError: (Object error) {
        developer.log(
          'Error in my videos subscription: $error',
          name: 'VideosRepository',
        );
      },
    );

    _isSubscribed = true;

    developer.log(
      'Subscribed to my videos',
      name: 'VideosRepository',
    );
  }

  /// Get video count for any user (one-time fetch).
  ///
  /// Queries Nostr relays for NIP-71 video events authored by the given pubkey.
  Future<int> getVideoCount(String pubkey) async {
    if (pubkey.isEmpty) return 0;

    developer.log(
      'Fetching video count for $pubkey',
      name: 'VideosRepository',
    );

    final events = await _nostrClient.queryEvents([
      Filter(
        authors: [pubkey],
        kinds: _videoKinds,
      ),
    ]);

    developer.log(
      'Video count for $pubkey: ${events.length}',
      name: 'VideosRepository',
    );

    return events.length;
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await _myVideosSubscription?.cancel();
    if (_subscriptionId != null) {
      await _nostrClient.unsubscribe(_subscriptionId!);
      _subscriptionId = null;
    }
    await _myVideoCountSubject.close();
    _isSubscribed = false;

    developer.log(
      'VideosRepository disposed',
      name: 'VideosRepository',
    );
  }
}
