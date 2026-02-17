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
    this.error,
    this.isLoadingMore = false,
    this.hasMoreContent = true,
    this.paginationCursor,
  });

  /// The current loading status.
  final ProfileCollabVideosStatus status;

  /// The list of collab videos.
  final List<VideoEvent> videos;

  /// Error message if loading failed, if any.
  final String? error;

  /// Whether more videos are being loaded (pagination).
  final bool isLoadingMore;

  /// Whether there are more videos to load.
  final bool hasMoreContent;

  /// Unix timestamp cursor for relay `until` pagination.
  final int? paginationCursor;

  /// Whether data has been successfully loaded.
  bool get isLoaded => status == ProfileCollabVideosStatus.success;

  /// Whether the state is currently loading.
  bool get isLoading => status == ProfileCollabVideosStatus.loading;

  /// Create a copy with updated values.
  ProfileCollabVideosState copyWith({
    ProfileCollabVideosStatus? status,
    List<VideoEvent>? videos,
    String? error,
    bool clearError = false,
    bool? isLoadingMore,
    bool? hasMoreContent,
    int? paginationCursor,
  }) {
    return ProfileCollabVideosState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      error: clearError ? null : (error ?? this.error),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      paginationCursor: paginationCursor ?? this.paginationCursor,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    error,
    isLoadingMore,
    hasMoreContent,
    paginationCursor,
  ];
}
