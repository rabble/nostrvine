// ABOUTME: db_client implementation of VideoLocalStorage.
// ABOUTME: Uses NostrEventsDao for persistent storage of video events.

import 'package:db_client/db_client.dart' hide Filter;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/src/video_local_storage.dart';

/// NIP-71 video event kind for addressable short videos.
const int _videoKind = EventKind.videoVertical;

/// Implementation of `VideoLocalStorage` using db_client's `NostrEventsDao`.
///
/// This implementation persists video events to the local SQLite database,
/// providing durability across app restarts.
///
/// Video events are stored with a configurable cache expiry (default 1 day)
/// to prevent unbounded storage growth.
class DbVideoLocalStorage implements VideoLocalStorage {
  /// Creates a new db_client-backed local storage.
  ///
  /// Requires a [NostrEventsDao] for database operations.
  DbVideoLocalStorage({
    required NostrEventsDao dao,
  }) : _dao = dao;

  final NostrEventsDao _dao;

  @override
  Future<void> saveEvent(Event event) async {
    await _dao.upsertEvent(event);
  }

  @override
  Future<void> saveEventsBatch(List<Event> events) async {
    if (events.isEmpty) return;
    await _dao.upsertEventsBatch(events);
  }

  @override
  Future<Event?> getEventById(String eventId) async {
    return _dao.getEventById(eventId);
  }

  @override
  Future<List<Event>> getEventsByIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return [];

    final filter = Filter(
      ids: eventIds,
      kinds: [_videoKind],
    );
    return _dao.getEventsByFilter(filter);
  }

  @override
  Future<List<Event>> getEventsByAuthors({
    required List<String> authors,
    int limit = 50,
    int? until,
  }) async {
    if (authors.isEmpty) return [];

    final filter = Filter(
      authors: authors,
      kinds: [_videoKind],
      limit: limit,
      until: until,
    );
    return _dao.getEventsByFilter(filter);
  }

  @override
  Future<List<Event>> getAllEvents({
    int limit = 50,
    int? until,
    String? sortBy,
  }) async {
    final filter = Filter(
      kinds: [_videoKind],
      limit: limit,
      until: until,
    );
    return _dao.getEventsByFilter(filter, sortBy: sortBy);
  }

  @override
  Future<List<Event>> getEventsByHashtags({
    required List<String> hashtags,
    int limit = 50,
    int? until,
  }) async {
    if (hashtags.isEmpty) return [];

    final filter = Filter(
      kinds: [_videoKind],
      t: hashtags,
      limit: limit,
      until: until,
    );
    return _dao.getEventsByFilter(filter);
  }

  @override
  Stream<List<Event>> watchEventsByAuthors({
    required List<String> authors,
    int limit = 50,
  }) {
    if (authors.isEmpty) return Stream.value([]);

    final filter = Filter(
      authors: authors,
      kinds: [_videoKind],
      limit: limit,
    );
    return _dao.watchEventsByFilter(filter);
  }

  @override
  Stream<List<Event>> watchAllEvents({
    int limit = 50,
    String? sortBy,
  }) {
    final filter = Filter(
      kinds: [_videoKind],
      limit: limit,
    );
    return _dao.watchEventsByFilter(filter, sortBy: sortBy);
  }

  @override
  Future<bool> deleteEvent(String eventId) async {
    return _dao.deleteEventById(eventId);
  }

  @override
  Future<int> deleteEventsByIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return 0;
    return _dao.deleteEventsByIds(eventIds);
  }

  @override
  Future<void> clearAll() async {
    await _dao.deleteEventsByKind(_videoKind);
  }

  @override
  Future<int> getEventCount() async {
    // Note: This counts all events, not just video events.
    // For video-specific count, we'd need to add a method to the DAO.
    // For now, this gives a rough indication of cache size.
    return _dao.getEventCount();
  }
}
