// ABOUTME: Abstract interface for local storage of like records.
// ABOUTME: Allows the repository to be decoupled from specific storage
// ABOUTME: implementations (db_client, Hive, etc.).

import 'package:likes_repository/src/models/like_record.dart';

/// Abstract interface for local storage of like records.
///
/// This interface allows the `LikesRepository` to persist like records
/// locally without being coupled to a specific storage implementation.
///
/// Implementations can use different storage backends:
/// - `DbLikesLocalStorage` uses db_client's PersonalReactionsDao
/// - In-memory implementations for testing
abstract class LikesLocalStorage {
  /// Saves a like record to local storage.
  ///
  /// If a record with the same [LikeRecord.targetEventId] already exists,
  /// it will be replaced.
  Future<void> saveLikeRecord(LikeRecord record);

  /// Saves multiple like records in a batch operation.
  ///
  /// More efficient than calling [saveLikeRecord] repeatedly.
  Future<void> saveLikeRecordsBatch(List<LikeRecord> records);

  /// Deletes a like record by target event ID.
  ///
  /// Returns `true` if a record was deleted, `false` if no record existed.
  Future<bool> deleteLikeRecord(String targetEventId);

  /// Gets a like record by target event ID.
  ///
  /// Returns `null` if no record exists for the given target.
  Future<LikeRecord?> getLikeRecord(String targetEventId);

  /// Gets the reaction event ID for a target event.
  ///
  /// This is a convenience method that returns just the reaction event ID,
  /// which is needed for creating deletion events when unliking.
  ///
  /// Returns `null` if the event is not liked.
  Future<String?> getReactionEventId(String targetEventId);

  /// Gets all like records.
  Future<List<LikeRecord>> getAllLikeRecords();

  /// Gets the set of all liked event IDs.
  Future<Set<String>> getLikedEventIds();

  /// Checks if an event is liked.
  Future<bool> isLiked(String targetEventId);

  /// Watches all liked event IDs (reactive stream).
  ///
  /// Emits an ordered list (most recent first) whenever likes change.
  Stream<List<String>> watchLikedEventIds();

  /// Clears all like records.
  ///
  /// Used when logging out or resetting local data.
  Future<void> clearAll();
}
