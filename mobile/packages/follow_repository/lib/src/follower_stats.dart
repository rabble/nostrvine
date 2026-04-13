import 'package:meta/meta.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Callback to check if the device is currently online
typedef IsOnlineCallback = bool Function();

/// Callback to queue an action for offline sync
typedef QueueOfflineFollowCallback =
    Future<void> Function({required bool isFollow, required String pubkey});

/// Callback to query a contact list from a relay event stream.
///
/// Implementations should listen to [eventStream] for a contact list event
/// authored by [pubkey] and return the first match, with a timeout of
/// [fallbackTimeoutSeconds].
typedef QueryContactListCallback =
    Future<Event?> Function({
      required Stream<Event> eventStream,
      required String pubkey,
      int fallbackTimeoutSeconds,
    });

/// Callback to check if personal event cache is initialized.
typedef IsCacheInitializedCallback = bool Function();

/// Callback to get cached events by kind from personal event cache.
typedef GetCachedEventsByKindCallback = List<Event> Function(int kind);

/// Callback to cache a user-authored event in personal event cache.
typedef CacheUserEventCallback = void Function(Event event);

/// Factory for creating relay instances.
///
/// Defaults to [RelayBase]. Override in tests to inject mock relays.
typedef RelayFactory = RelayBase Function(String url, RelayStatus status);

/// Immutable follower/following counts for a pubkey.
@immutable
class FollowerStats {
  const FollowerStats({required this.followers, required this.following});

  final int followers;
  final int following;

  static const zero = FollowerStats(followers: 0, following: 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowerStats &&
          followers == other.followers &&
          following == other.following;

  @override
  int get hashCode => Object.hash(followers, following);

  @override
  String toString() =>
      'FollowerStats(followers: $followers, following: $following)';
}
