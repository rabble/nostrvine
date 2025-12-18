// ABOUTME: Likes state model for managing user's liked events
// ABOUTME: Used by Riverpod LikesNotifier to manage reactive like interaction state

import 'package:freezed_annotation/freezed_annotation.dart';

part 'likes_state.freezed.dart';
part 'likes_state.g.dart';

/// State model for likes feature
///
/// Tracks which events the user has liked, maps target event IDs to their
/// reaction event IDs (needed for unlikes), and manages loading states.
@freezed
sealed class LikesState with _$LikesState {
  const factory LikesState({
    /// Set of event IDs that the user has liked
    @Default({}) Set<String> likedEventIds,

    /// Map from target event ID to the reaction event ID
    /// Required for publishing Kind 5 deletion events when unliking
    @Default({}) Map<String, String> eventIdToReactionId,

    /// Map from event ID to like count (public likes from all users)
    @Default({}) Map<String, int> likeCounts,

    /// Whether the state has been initialized from local storage/relays
    @Default(false) bool isInitialized,

    /// Whether initial sync is in progress
    @Default(false) bool isSyncing,

    /// Set of event IDs with like operations currently in progress
    /// Prevents duplicate operations on the same event
    @Default({}) Set<String> operationsInProgress,

    /// Last error that occurred, if any
    String? error,
  }) = _LikesState;

  factory LikesState.fromJson(Map<String, dynamic> json) =>
      _$LikesStateFromJson(json);

  const LikesState._();

  /// Initial state before any data is loaded
  static const LikesState initial = LikesState();

  /// Check if the user has liked an event
  bool isLiked(String eventId) => likedEventIds.contains(eventId);

  /// Check if a like/unlike operation is in progress for an event
  bool isOperationInProgress(String eventId) =>
      operationsInProgress.contains(eventId);

  /// Get the reaction event ID for a liked event
  /// Returns null if the event is not liked
  String? getReactionEventId(String eventId) => eventIdToReactionId[eventId];

  /// Get the like count for an event
  /// Returns 0 if no count is cached
  int getLikeCount(String eventId) => likeCounts[eventId] ?? 0;
}
