// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popular_videos_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates native fetching to [VideosRepository.getNativePopularVideos], which
/// uses the native-only leaderboard and falls back through the legacy popular
/// feed path when Funnelcake is unavailable.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change

@ProviderFor(PopularVideosFeed)
const popularVideosFeedProvider = PopularVideosFeedProvider._();

/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates native fetching to [VideosRepository.getNativePopularVideos], which
/// uses the native-only leaderboard and falls back through the legacy popular
/// feed path when Funnelcake is unavailable.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change
final class PopularVideosFeedProvider
    extends $AsyncNotifierProvider<PopularVideosFeed, VideoFeedState> {
  /// Popular Videos feed provider - shows trending videos by recent engagement.
  ///
  /// Delegates native fetching to [VideosRepository.getNativePopularVideos], which
  /// uses the native-only leaderboard and falls back through the legacy popular
  /// feed path when Funnelcake is unavailable.
  ///
  /// Rebuilds when:
  /// - Pull to refresh
  /// - appReady gate becomes true
  /// - Content filter preferences change
  const PopularVideosFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'popularVideosFeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$popularVideosFeedHash();

  @$internal
  @override
  PopularVideosFeed create() => PopularVideosFeed();
}

String _$popularVideosFeedHash() => r'b84b5be906df65474ad942fe5abd564669fea02b';

/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates native fetching to [VideosRepository.getNativePopularVideos], which
/// uses the native-only leaderboard and falls back through the legacy popular
/// feed path when Funnelcake is unavailable.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change

abstract class _$PopularVideosFeed extends $AsyncNotifier<VideoFeedState> {
  FutureOr<VideoFeedState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<VideoFeedState>, VideoFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideoFeedState>, VideoFeedState>,
              AsyncValue<VideoFeedState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
