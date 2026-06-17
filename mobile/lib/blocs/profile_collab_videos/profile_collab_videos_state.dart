// ABOUTME: State class for the ProfileCollabVideosBloc
// ABOUTME: Represents the loading state and video list for profile collab videos

part of 'profile_collab_videos_bloc.dart';

/// Enum representing the status of collab videos loading.
enum ProfileCollabVideosStatus {
  /// Initial state, no data loaded yet.
  initial,

  /// Currently loading collab videos.
  loading,

  /// Collab videos loaded successfully.
  success,

  /// An error occurred while loading collab videos.
  failure,
}

/// State class for the ProfileCollabVideosBloc.
///
/// Contains:
/// - [videos]: The list of collab video events
/// - [status]: The current loading status
/// - [error]: Any error message
/// - [isLoadingMore]: Whether more videos are being loaded (pagination)
/// - [hasMoreContent]: Whether there are more videos to load
/// - [paginationCursor]: Unix timestamp cursor for relay pagination
final class ProfileCollabVideosState extends Equatable {
  const ProfileCollabVideosState({
    this.status = ProfileCollabVideosStatus.initial,
    this.videos = const [],
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.hasMoreContent = true,
    this.paginationCursor,
  });

  /// The current loading status.
  final ProfileCollabVideosStatus status;

  /// The list of collab videos.
  final List<VideoEvent> videos;

  /// Whether more videos are being loaded (pagination).
  final bool isLoadingMore;

  /// Whether a background revalidation is in progress while cached content is
  /// already on screen. Drives the sticky progress bar in the tab bar.
  final bool isRefreshing;

  /// Whether there are more videos to load.
  final bool hasMoreContent;

  /// Unix timestamp cursor for relay `until` pagination.
  final int? paginationCursor;

  /// Whether data has been successfully loaded.
  bool get isLoaded => status == ProfileCollabVideosStatus.success;

  /// Whether the state is currently loading.
  bool get isLoading => status == ProfileCollabVideosStatus.loading;

  /// Create a copy with updated values.
  ///
  /// Pass [clearCursor] to reset [paginationCursor] back to `null` (the
  /// end-of-feed signal) — a plain `paginationCursor: null` cannot do this
  /// because the null-coalescing fallback would keep the old value.
  ProfileCollabVideosState copyWith({
    ProfileCollabVideosStatus? status,
    List<VideoEvent>? videos,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? hasMoreContent,
    int? paginationCursor,
    bool clearCursor = false,
  }) {
    return ProfileCollabVideosState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      paginationCursor: clearCursor
          ? null
          : (paginationCursor ?? this.paginationCursor),
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    isLoadingMore,
    isRefreshing,
    hasMoreContent,
    paginationCursor,
  ];
}
