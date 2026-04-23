// ABOUTME: State class for the ProfileSavedVideosBloc
// ABOUTME: Represents the syncing/loading state and video list for saved (bookmarked) videos

part of 'profile_saved_videos_bloc.dart';

/// Enum representing the status of saved videos loading.
enum ProfileSavedVideosStatus {
  /// Initial state, no data loaded yet.
  initial,

  /// Currently loading bookmark IDs from [BookmarkService].
  syncing,

  /// Currently loading video data for bookmark IDs.
  loading,

  /// Saved videos loaded successfully.
  success,

  /// An error occurred while loading saved videos.
  failure,
}

/// Error types for l10n-friendly error handling.
enum ProfileSavedVideosError {
  /// Failed to load saved videos from cache or relays.
  loadFailed,
}

/// State class for the [ProfileSavedVideosBloc].
final class ProfileSavedVideosState extends Equatable {
  const ProfileSavedVideosState({
    this.status = ProfileSavedVideosStatus.initial,
    this.videos = const [],
    this.savedEventIds = const [],
    this.error,
    this.isLoadingMore = false,
    this.hasMoreContent = true,
    this.nextPageOffset = 0,
  });

  /// The current loading status.
  final ProfileSavedVideosStatus status;

  /// The list of saved videos, ordered as returned by [BookmarkService]
  /// (most recently saved first).
  final List<VideoEvent> videos;

  /// The bookmark event IDs backing the current video list.
  final List<String> savedEventIds;

  /// Error that occurred during loading, if any.
  final ProfileSavedVideosError? error;

  /// Whether more videos are being loaded (pagination).
  final bool isLoadingMore;

  /// Whether there are more videos to load.
  final bool hasMoreContent;

  /// Offset into [savedEventIds] for the next page fetch. Tracks how many
  /// IDs have been consumed, independent of how many videos were actually
  /// loaded (some IDs may not resolve due to relay unavailability or
  /// unsupported format filtering).
  final int nextPageOffset;

  /// Whether data has been successfully loaded.
  bool get isLoaded => status == ProfileSavedVideosStatus.success;

  /// Whether the state is currently loading or syncing.
  bool get isLoading =>
      status == ProfileSavedVideosStatus.loading ||
      status == ProfileSavedVideosStatus.syncing;

  ProfileSavedVideosState copyWith({
    ProfileSavedVideosStatus? status,
    List<VideoEvent>? videos,
    List<String>? savedEventIds,
    ProfileSavedVideosError? error,
    bool clearError = false,
    bool? isLoadingMore,
    bool? hasMoreContent,
    int? nextPageOffset,
  }) {
    return ProfileSavedVideosState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      savedEventIds: savedEventIds ?? this.savedEventIds,
      error: clearError ? null : (error ?? this.error),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      nextPageOffset: nextPageOffset ?? this.nextPageOffset,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    savedEventIds,
    error,
    isLoadingMore,
    hasMoreContent,
    nextPageOffset,
  ];
}
