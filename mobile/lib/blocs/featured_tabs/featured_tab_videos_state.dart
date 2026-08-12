// ABOUTME: State for FeaturedTabVideosCubit: server-ordered videos and paging.
// ABOUTME: Order is the server's; the client never re-sorts.

part of 'featured_tab_videos_cubit.dart';

/// Lifecycle of a featured tab's video feed.
enum FeaturedTabVideosStatus {
  /// Nothing loaded yet.
  initial,

  /// The first page is loading.
  loading,

  /// At least one page has loaded.
  ready,

  /// A page request failed.
  failure,
}

/// Videos for one featured tab, in server order.
class FeaturedTabVideosState extends Equatable {
  /// Creates a featured tab videos state.
  const FeaturedTabVideosState({
    this.status = FeaturedTabVideosStatus.initial,
    this.videos = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  /// Fetch lifecycle for the first page.
  final FeaturedTabVideosStatus status;

  /// Loaded videos, in the order the server returned them.
  final List<VideoEvent> videos;

  /// Opaque cursor for the next page.
  final String? nextCursor;

  /// Whether another page is available.
  final bool hasMore;

  /// Whether a follow-up page is in flight.
  final bool isLoadingMore;

  /// Whether the tab has loaded and has nothing to show.
  ///
  /// The server refreshes its content snapshot on a 15-minute cadence, so an
  /// empty page for an otherwise-eligible tab is transient rather than final.
  bool get isEmpty => status == FeaturedTabVideosStatus.ready && videos.isEmpty;

  /// Returns a copy with the given overrides.
  FeaturedTabVideosState copyWith({
    FeaturedTabVideosStatus? status,
    List<VideoEvent>? videos,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return FeaturedTabVideosState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    nextCursor,
    hasMore,
    isLoadingMore,
  ];
}
