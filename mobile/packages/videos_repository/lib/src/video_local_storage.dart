// ABOUTME: Abstract interface for local storage of video events.
// ABOUTME: Allows the repository to be decoupled from specific storage
// ABOUTME: implementations (db_client, Hive, etc.).

import 'package:nostr_sdk/nostr_sdk.dart';

/// Abstract interface for local storage of video events.
///
/// This interface allows the `VideosRepository` to persist video events
/// locally without being coupled to a specific storage implementation.
///
/// Implementations can use different storage backends:
/// - `DbVideoLocalStorage` uses db_client's NostrEventsDao
/// - In-memory implementations for testing
///
/// The storage works with raw Nostr [Event] objects. Transformation to
/// domain models (e.g., `VideoEvent`) happens at the repository level.
abstract class VideoLocalStorage {
  /// Saves a video event to local storage.
  ///
  /// If an event with the same ID already exists, it will be replaced.
  /// For addressable events (kind 30000-39999), follows NIP-33 replacement
  /// rules: only replaces if the new event has a higher created_at.
  Future<void> saveEvent(Event event);

  /// Saves multiple video events in a batch operation.
  ///
  /// More efficient than calling [saveEvent] repeatedly.
  Future<void> saveEventsBatch(List<Event> events);

  /// Gets a video event by its event ID.
  ///
  /// Returns `null` if no event exists with the given ID.
  Future<Event?> getEventById(String eventId);

  /// Gets video events by a list of event IDs.
  ///
  /// Returns only the events that were found. Missing IDs are silently
  /// ignored.
  Future<List<Event>> getEventsByIds(List<String> eventIds);

  /// Gets video events by author pubkeys.
  ///
  /// Useful for home feed (videos from followed users) and profile feed.
  ///
  /// Parameters:
  /// - [authors]: List of pubkeys to filter by
  /// - [limit]: Maximum number of events to return (default 50)
  /// - [until]: Only return events created before this Unix timestamp
  Future<List<Event>> getEventsByAuthors({
    required List<String> authors,
    int limit = 50,
    int? until,
  });

  /// Gets all video events (discovery feed).
  ///
  /// Parameters:
  /// - [limit]: Maximum number of events to return (default 50)
  /// - [until]: Only return events created before this Unix timestamp
  /// - [sortBy]: Field to sort by ('created_at', 'loop_count', 'likes')
  Future<List<Event>> getAllEvents({
    int limit = 50,
    int? until,
    String? sortBy,
  });

  /// Gets video events by hashtags.
  ///
  /// Parameters:
  /// - [hashtags]: List of hashtags to filter by (without #)
  /// - [limit]: Maximum number of events to return (default 50)
  /// - [until]: Only return events created before this Unix timestamp
  Future<List<Event>> getEventsByHashtags({
    required List<String> hashtags,
    int limit = 50,
    int? until,
  });

  /// Watches video events by author pubkeys (reactive stream).
  ///
  /// Emits a new list whenever matching events change in the database.
  Stream<List<Event>> watchEventsByAuthors({
    required List<String> authors,
    int limit = 50,
  });

  /// Watches all video events (reactive stream).
  ///
  /// Emits a new list whenever video events change in the database.
  Stream<List<Event>> watchAllEvents({
    int limit = 50,
    String? sortBy,
  });

  /// Deletes a video event by its event ID.
  ///
  /// Returns `true` if an event was deleted, `false` if no event existed.
  Future<bool> deleteEvent(String eventId);

  /// Deletes multiple video events by their event IDs.
  ///
  /// Returns the number of events deleted.
  Future<int> deleteEventsByIds(List<String> eventIds);

  /// Clears all video events from local storage.
  ///
  /// Used when logging out or resetting local data.
  Future<void> clearAll();

  /// Gets the count of cached video events.
  Future<int> getEventCount();
}
