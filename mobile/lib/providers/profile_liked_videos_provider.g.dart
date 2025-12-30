// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_liked_videos_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that returns videos the current user has liked
///
/// Combines liked event IDs from likesProvider with video data from:
/// 1. Local cache (VideoEventService)
/// 2. Relay queries for any missing videos

@ProviderFor(ProfileLikedVideos)
const profileLikedVideosProvider = ProfileLikedVideosProvider._();

/// Provider that returns videos the current user has liked
///
/// Combines liked event IDs from likesProvider with video data from:
/// 1. Local cache (VideoEventService)
/// 2. Relay queries for any missing videos
final class ProfileLikedVideosProvider
    extends $AsyncNotifierProvider<ProfileLikedVideos, List<VideoEvent>> {
  /// Provider that returns videos the current user has liked
  ///
  /// Combines liked event IDs from likesProvider with video data from:
  /// 1. Local cache (VideoEventService)
  /// 2. Relay queries for any missing videos
  const ProfileLikedVideosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileLikedVideosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileLikedVideosHash();

  @$internal
  @override
  ProfileLikedVideos create() => ProfileLikedVideos();
}

String _$profileLikedVideosHash() =>
    r'bc0bfc61257c5233a326eba4e3e939b35d6296ce';

/// Provider that returns videos the current user has liked
///
/// Combines liked event IDs from likesProvider with video data from:
/// 1. Local cache (VideoEventService)
/// 2. Relay queries for any missing videos

abstract class _$ProfileLikedVideos extends $AsyncNotifier<List<VideoEvent>> {
  FutureOr<List<VideoEvent>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<VideoEvent>>, List<VideoEvent>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<VideoEvent>>, List<VideoEvent>>,
              AsyncValue<List<VideoEvent>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider that wraps liked videos into VideoFeedState for route-based video tracking

@ProviderFor(likedVideosFeedState)
const likedVideosFeedStateProvider = LikedVideosFeedStateProvider._();

/// Provider that wraps liked videos into VideoFeedState for route-based video tracking

final class LikedVideosFeedStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<VideoFeedState>,
          VideoFeedState,
          FutureOr<VideoFeedState>
        >
    with $FutureModifier<VideoFeedState>, $FutureProvider<VideoFeedState> {
  /// Provider that wraps liked videos into VideoFeedState for route-based video tracking
  const LikedVideosFeedStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'likedVideosFeedStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$likedVideosFeedStateHash();

  @$internal
  @override
  $FutureProviderElement<VideoFeedState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VideoFeedState> create(Ref ref) {
    return likedVideosFeedState(ref);
  }
}

String _$likedVideosFeedStateHash() =>
    r'8ad7db26d10a0b382704f45ef9e8d23b2c8ad1f4';
