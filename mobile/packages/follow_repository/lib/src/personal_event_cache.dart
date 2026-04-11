import 'package:nostr_sdk/nostr_sdk.dart';

/// Abstract interface for personal event caching.
///
/// The follow repository uses this to read/write contact list events
/// without being coupled to a specific storage implementation (e.g. Hive).
abstract class PersonalEventCache {
  /// Whether the cache has been initialized for the current user.
  bool get isInitialized;

  /// Returns all cached events of the given [kind].
  List<Event> getEventsByKind(int kind);

  /// Caches a user-authored [event] for later retrieval.
  void cacheUserEvent(Event event);
}
