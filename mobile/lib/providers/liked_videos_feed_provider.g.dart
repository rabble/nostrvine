// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'liked_videos_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that returns liked videos as VideoFeedState for route-based video
/// tracking.
///
/// This provider:
/// 1. Watches LikesRepository for the list of liked event IDs
/// 2. Fetches video data from cache and relays
/// 3. Returns VideoFeedState for use by active_video_provider

@ProviderFor(likedVideosFeed)
const likedVideosFeedProvider = LikedVideosFeedProvider._();

/// Provider that returns liked videos as VideoFeedState for route-based video
/// tracking.
///
/// This provider:
/// 1. Watches LikesRepository for the list of liked event IDs
/// 2. Fetches video data from cache and relays
/// 3. Returns VideoFeedState for use by active_video_provider

final class LikedVideosFeedProvider
    extends
        $FunctionalProvider<
          AsyncValue<VideoFeedState>,
          VideoFeedState,
          FutureOr<VideoFeedState>
        >
    with $FutureModifier<VideoFeedState>, $FutureProvider<VideoFeedState> {
  /// Provider that returns liked videos as VideoFeedState for route-based video
  /// tracking.
  ///
  /// This provider:
  /// 1. Watches LikesRepository for the list of liked event IDs
  /// 2. Fetches video data from cache and relays
  /// 3. Returns VideoFeedState for use by active_video_provider
  const LikedVideosFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'likedVideosFeedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$likedVideosFeedHash();

  @$internal
  @override
  $FutureProviderElement<VideoFeedState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VideoFeedState> create(Ref ref) {
    return likedVideosFeed(ref);
  }
}

String _$likedVideosFeedHash() => r'ae9e38702de27caaa5eacbf977ebc2bd04d63bce';
