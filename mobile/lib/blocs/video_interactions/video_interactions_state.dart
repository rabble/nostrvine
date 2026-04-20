// ABOUTME: State for VideoInteractionsBloc
// ABOUTME: Tracks like/repost status, counts, and loading states for a video

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
/// - [isReposted]: Whether the current user has reposted this video
/// - [repostCount]: Total number of reposts on this video
/// - [commentCount]: Total number of comments on this video
/// - [isCommentsInProgress]: Whether a comments operation is in progress
///
/// Like-toggle and repost-toggle no longer carry in-progress flags: their
/// repositories write the optimistic record + emit before the network call,
/// and this bloc emits the optimistic count + status before awaiting, so the
/// UI flips immediately and rolls back on failure. See
/// [LikesRepository.likeEvent] and [RepostsRepository.repostVideo].
/// - [lastActionFeedback]: Publish feedback from the most recent like/repost
///   toggle, surfaced so the UI can render a retry-aware snackbar. Cleared
///   when the user begins a new action.
class VideoInteractionsState extends Equatable {
  const VideoInteractionsState({
    this.status = VideoInteractionsStatus.initial,
    this.isLiked = false,
    this.likeCount,
    this.isReposted = false,
    this.repostCount,
    this.commentCount,
    this.isCommentsInProgress = false,
    this.error,
    this.lastActionFeedback,
  });

  /// Current status of the bloc.
  final VideoInteractionsStatus status;

  /// Whether the current user has liked this video.
  final bool isLiked;

  /// Total number of likes on this video.
  /// Null if not yet fetched.
  final int? likeCount;

  /// Whether the current user has reposted this video.
  final bool isReposted;

  /// Total number of reposts on this video.
  /// Null if not yet fetched.
  final int? repostCount;

  /// Total number of comments on this video.
  /// Null if not yet fetched.
  final int? commentCount;

  /// Whether a comments operation is currently in progress.
  final bool isCommentsInProgress;

  /// Error that occurred, if any.
  final VideoInteractionsError? error;

  /// User-facing feedback describing the most recent failed like/repost
  /// action, derived from [PublishResultMapper]. The UI reads this to show
  /// a retry-aware snackbar and clears it on the next action.
  final PublishUserFeedback? lastActionFeedback;

  /// Whether interaction counts are still loading.
  bool get isLoading =>
      status == VideoInteractionsStatus.initial ||
      status == VideoInteractionsStatus.loading;

  /// Whether counts have been fetched.
  bool get hasLoadedCounts => likeCount != null;

  /// Creates a copy with the specified fields replaced.
  VideoInteractionsState copyWith({
    VideoInteractionsStatus? status,
    bool? isLiked,
    int? likeCount,
    bool? isReposted,
    int? repostCount,
    int? commentCount,
    bool? isCommentsInProgress,
    VideoInteractionsError? error,
    PublishUserFeedback? lastActionFeedback,
    bool clearError = false,
    bool clearFeedback = false,
  }) {
    return VideoInteractionsState(
      status: status ?? this.status,
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      isReposted: isReposted ?? this.isReposted,
      repostCount: repostCount ?? this.repostCount,
      commentCount: commentCount ?? this.commentCount,
      isCommentsInProgress: isCommentsInProgress ?? this.isCommentsInProgress,
      error: clearError ? null : (error ?? this.error),
      lastActionFeedback: clearFeedback
          ? null
          : (lastActionFeedback ?? this.lastActionFeedback),
    );
  }

  @override
  List<Object?> get props => [
    status,
    isLiked,
    likeCount,
    isReposted,
    repostCount,
    commentCount,
    isCommentsInProgress,
    error,
    lastActionFeedback,
  ];
}

/// Errors that can occur in video interactions.
enum VideoInteractionsError {
  /// Failed to fetch counts.
  fetchFailed,

  /// Failed to toggle like.
  likeFailed,

  /// Failed to toggle repost.
  repostFailed,
}
