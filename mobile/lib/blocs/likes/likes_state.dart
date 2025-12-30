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

/// State class for the LikesBloc.
///
/// Contains minimal state needed for the UI:
/// - [likedEventIds]: Ordered list of liked event IDs (most recent first)
/// - [operationsInProgress]: Events currently being liked/unliked
///
/// The repository handles internal details like reaction event IDs.
final class LikesState extends Equatable {
  const LikesState({
    this.status = LikesStatus.initial,
    this.likedEventIds = const [],
    this.operationsInProgress = const {},
    this.error,
  });

  /// The current status of likes sync
  final LikesStatus status;

  /// Liked event IDs ordered by recency (most recently liked first).
  ///
  /// This is the single source of truth for what the user has liked.
  /// Use [isLiked] for checking if a specific event is liked.
  final List<String> likedEventIds;

  /// Set of event IDs with like operations currently in progress.
  ///
  /// Used to prevent duplicate operations and show loading state in UI.
  final Set<String> operationsInProgress;

  /// Error type for l10n-friendly error handling.
  ///
  /// UI layer maps this to localized string via BlocListener.
  final LikesError? error;

  /// Check if the user has liked an event.
  bool isLiked(String eventId) => likedEventIds.contains(eventId);

  /// Check if a like/unlike operation is in progress for an event.
  bool isOperationInProgress(String eventId) =>
      operationsInProgress.contains(eventId);

  /// Whether the state has been successfully initialized.
  bool get isInitialized => status == LikesStatus.success;

  /// The number of liked events.
  int get likeCount => likedEventIds.length;

  /// Create a copy with updated values.
  LikesState copyWith({
    LikesStatus? status,
    List<String>? likedEventIds,
    Set<String>? operationsInProgress,
    LikesError? error,
    bool clearError = false,
  }) {
    return LikesState(
      status: status ?? this.status,
      likedEventIds: likedEventIds ?? this.likedEventIds,
      operationsInProgress: operationsInProgress ?? this.operationsInProgress,
      error: clearError ? null : error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    likedEventIds,
    operationsInProgress,
    error,
  ];
}
