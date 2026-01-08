// ABOUTME: State for VideoInteractionsBloc
// ABOUTME: Tracks like status, counts, and loading states for a single video

part of 'video_interactions_bloc.dart';

/// Status of the video interactions bloc.
enum VideoInteractionsStatus {
  /// Initial state before any data is fetched.
  initial,

  /// Currently fetching data.
  loading,

  /// Data loaded successfully.
  success,

  /// Failed to load data.
  failure,
}

/// State for a single video's interactions.
///
/// Contains:
/// - [isLiked]: Whether the current user has liked this video
/// - [likeCount]: Total number of likes on this video
/// - [commentCount]: Total number of comments on this video
/// - [isLikeInProgress]: Whether a like/unlike operation is in progress
class VideoInteractionsState extends Equatable {
  const VideoInteractionsState({
    this.status = VideoInteractionsStatus.initial,
    this.isLiked = false,
    this.likeCount,
    this.commentCount,
    this.isLikeInProgress = false,
    this.error,
  });

  /// Current status of the bloc.
  final VideoInteractionsStatus status;

  /// Whether the current user has liked this video.
  final bool isLiked;

  /// Total number of likes on this video.
  /// Null if not yet fetched.
  final int? likeCount;

  /// Total number of comments on this video.
  /// Null if not yet fetched.
  final int? commentCount;

  /// Whether a like/unlike operation is currently in progress.
  final bool isLikeInProgress;

  /// Error that occurred, if any.
  final VideoInteractionsError? error;

  /// Whether counts have been fetched.
  bool get hasLoadedCounts => likeCount != null;

  /// Creates a copy with the specified fields replaced.
  VideoInteractionsState copyWith({
    VideoInteractionsStatus? status,
    bool? isLiked,
    int? likeCount,
    int? commentCount,
    bool? isLikeInProgress,
    VideoInteractionsError? error,
    bool clearError = false,
  }) {
    return VideoInteractionsState(
      status: status ?? this.status,
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLikeInProgress: isLikeInProgress ?? this.isLikeInProgress,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    status,
    isLiked,
    likeCount,
    commentCount,
    isLikeInProgress,
    error,
  ];
}

/// Errors that can occur in video interactions.
enum VideoInteractionsError {
  /// Failed to fetch counts.
  fetchFailed,

  /// Failed to toggle like.
  likeFailed,
}
