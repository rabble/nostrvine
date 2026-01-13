// ABOUTME: State class for the ProfileLikedVideosBloc
// ABOUTME: Represents the syncing/loading state and video list for profile liked videos

part of 'profile_liked_videos_bloc.dart';

/// Enum representing the status of liked videos loading
enum ProfileLikedVideosStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently syncing liked event IDs from repository
  syncing,

  /// Currently loading video data for liked IDs
  loading,

  /// Liked videos loaded successfully
  success,

  /// An error occurred while loading liked videos
  failure,
}

/// Error types for l10n-friendly error handling.
enum ProfileLikedVideosError {
  /// Failed to sync liked event IDs from repository
  syncFailed,

  /// Failed to load liked videos from cache or relays
  loadFailed,
}

/// State class for the ProfileLikedVideosBloc.
///
/// Contains:
/// - [videos]: The list of liked video events (ordered by recency)
/// - [status]: The current loading status
/// - [error]: Any error that occurred
/// - [isLoadingMore]: Whether more videos are being loaded (pagination)
/// - [hasMoreContent]: Whether there are more videos to load
final class ProfileLikedVideosState extends Equatable {
  const ProfileLikedVideosState({
    this.status = ProfileLikedVideosStatus.initial,
    this.videos = const [],
    this.likedEventIds = const [],
    this.error,
    this.isLoadingMore = false,
    this.hasMoreContent = true,
  });

  /// The current loading status
  final ProfileLikedVideosStatus status;

  /// The list of liked videos, ordered by recency (most recently liked first)
  final List<VideoEvent> videos;

  /// The liked event IDs used for the current video list
  final List<String> likedEventIds;

  /// Error that occurred during loading, if any
  final ProfileLikedVideosError? error;

  /// Whether more videos are being loaded (pagination)
  final bool isLoadingMore;

  /// Whether there are more videos to load
  final bool hasMoreContent;

  /// Whether data has been successfully loaded
  bool get isLoaded => status == ProfileLikedVideosStatus.success;

  /// Whether the state is currently loading or syncing
  bool get isLoading =>
      status == ProfileLikedVideosStatus.loading ||
      status == ProfileLikedVideosStatus.syncing;

  /// Create a copy with updated values.
  ProfileLikedVideosState copyWith({
    ProfileLikedVideosStatus? status,
    List<VideoEvent>? videos,
    List<String>? likedEventIds,
    ProfileLikedVideosError? error,
    bool clearError = false,
    bool? isLoadingMore,
    bool? hasMoreContent,
  }) {
    return ProfileLikedVideosState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      likedEventIds: likedEventIds ?? this.likedEventIds,
      error: clearError ? null : (error ?? this.error),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    likedEventIds,
    error,
    isLoadingMore,
    hasMoreContent,
  ];
}
