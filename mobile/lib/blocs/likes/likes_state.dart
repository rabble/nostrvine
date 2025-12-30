// ABOUTME: State class for the LikesBloc
// ABOUTME: Represents all possible states of the user's likes

part of 'likes_bloc.dart';

/// Enum representing the status of the likes sync
enum LikesStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently syncing likes from storage/relays
  syncing,

  /// Likes loaded successfully
  success,

  /// An error occurred while syncing likes
  failure,
}

/// Error types for l10n-friendly error handling.
///
/// The UI layer should map these to localized strings via BlocListener.
enum LikesError {
  /// Failed to sync likes from relays/storage
  syncFailed,

  /// User must sign in to like content
  notAuthenticated,

  /// Failed to like an event
  likeFailed,

  /// Failed to unlike an event
  unlikeFailed,
}

/// State class for the LikesBloc
final class LikesState extends Equatable {
  const LikesState({
    this.status = LikesStatus.initial,
    this.likedEventIds = const {},
    this.orderedLikedEventIds = const [],
    this.eventIdToReactionId = const {},
    this.likeCounts = const {},
    this.operationsInProgress = const {},
    this.error,
  });

  /// The current status of likes sync
  final LikesStatus status;

  /// Set of event IDs that the user has liked (for O(1) lookup)
  final Set<String> likedEventIds;

  /// Liked event IDs ordered by recency (most recently liked first)
  /// Use this for displaying liked videos in order
  final List<String> orderedLikedEventIds;

  /// Map from target event ID to the reaction event ID
  /// Required for publishing Kind 5 deletion events when unliking
  final Map<String, String> eventIdToReactionId;

  /// Map from event ID to like count (public likes from all users)
  final Map<String, int> likeCounts;

  /// Set of event IDs with like operations currently in progress
  /// Prevents duplicate operations on the same event
  final Set<String> operationsInProgress;

  /// Error type for l10n-friendly error handling
  /// UI layer maps this to localized string via BlocListener
  final LikesError? error;

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

  /// Whether the state has been successfully initialized
  bool get isInitialized => status == LikesStatus.success;

  /// Create a copy with updated values
  LikesState copyWith({
    LikesStatus? status,
    Set<String>? likedEventIds,
    List<String>? orderedLikedEventIds,
    Map<String, String>? eventIdToReactionId,
    Map<String, int>? likeCounts,
    Set<String>? operationsInProgress,
    LikesError? error,
    bool clearError = false,
  }) {
    return LikesState(
      status: status ?? this.status,
      likedEventIds: likedEventIds ?? this.likedEventIds,
      orderedLikedEventIds: orderedLikedEventIds ?? this.orderedLikedEventIds,
      eventIdToReactionId: eventIdToReactionId ?? this.eventIdToReactionId,
      likeCounts: likeCounts ?? this.likeCounts,
      operationsInProgress: operationsInProgress ?? this.operationsInProgress,
      error: clearError ? null : error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    likedEventIds,
    orderedLikedEventIds,
    eventIdToReactionId,
    likeCounts,
    operationsInProgress,
    error,
  ];
}
