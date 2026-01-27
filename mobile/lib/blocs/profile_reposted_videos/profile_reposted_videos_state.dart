// ABOUTME: State class for the ProfileRepostedVideosBloc
// ABOUTME: Represents the syncing/loading state and video list for profile
// ABOUTME: reposted videos

part of 'profile_reposted_videos_bloc.dart';

/// Enum representing the status of reposted videos loading
enum ProfileRepostedVideosStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently syncing repost records from repository
  syncing,

  /// Currently loading video data for repost records
  loading,

  /// Reposted videos loaded successfully
  success,

  /// An error occurred while loading reposted videos
  failure,
}

/// Error types for l10n-friendly error handling.
enum ProfileRepostedVideosError {
  /// Failed to sync repost records from repository
  syncFailed,

  /// Failed to load reposted videos from cache or relays
  loadFailed,
}

/// State class for the ProfileRepostedVideosBloc.
///
/// Contains:
/// - [videos]: The list of reposted video events (ordered by recency)
/// - [status]: The current loading status
/// - [error]: Any error that occurred
/// - [isLoadingMore]: Whether more videos are being loaded (pagination)
/// - [hasMoreContent]: Whether there are more videos to load
final class ProfileRepostedVideosState extends Equatable {
  const ProfileRepostedVideosState({
    this.status = ProfileRepostedVideosStatus.initial,
    this.videos = const [],
    this.repostedAddressableIds = const [],
    this.error,
    this.isLoadingMore = false,
    this.hasMoreContent = true,
  });

  /// The current loading status
  final ProfileRepostedVideosStatus status;

  /// The list of reposted videos, ordered by recency (most recently reposted
  /// first)
  final List<VideoEvent> videos;

  /// The addressable IDs of reposted videos used for the current video list
  final List<String> repostedAddressableIds;

  /// Error that occurred during loading, if any
  final ProfileRepostedVideosError? error;

  /// Whether more videos are being loaded (pagination)
  final bool isLoadingMore;

  /// Whether there are more videos to load
  final bool hasMoreContent;

  /// Whether data has been successfully loaded
  bool get isLoaded => status == ProfileRepostedVideosStatus.success;

  /// Whether the state is currently loading or syncing
  bool get isLoading =>
      status == ProfileRepostedVideosStatus.loading ||
      status == ProfileRepostedVideosStatus.syncing;

  /// Create a copy with updated values.
  ProfileRepostedVideosState copyWith({
    ProfileRepostedVideosStatus? status,
    List<VideoEvent>? videos,
    List<String>? repostedAddressableIds,
    ProfileRepostedVideosError? error,
    bool clearError = false,
    bool? isLoadingMore,
    bool? hasMoreContent,
  }) {
    return ProfileRepostedVideosState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      repostedAddressableIds:
          repostedAddressableIds ?? this.repostedAddressableIds,
      error: clearError ? null : (error ?? this.error),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    repostedAddressableIds,
    error,
    isLoadingMore,
    hasMoreContent,
  ];
}
