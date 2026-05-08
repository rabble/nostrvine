// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popular_videos_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates video fetching to [VideosRepository.getPopularVideos], which
/// implements a 3-tier fallback: Funnelcake REST API → NIP-50 sort:hot →
/// client-side engagement sorting.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change
/// - Selected popular period changes (Right Now / Week / Month / All-Time)

@ProviderFor(PopularVideosFeed)
const popularVideosFeedProvider = PopularVideosFeedProvider._();

/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates video fetching to [VideosRepository.getPopularVideos], which
/// implements a 3-tier fallback: Funnelcake REST API → NIP-50 sort:hot →
/// client-side engagement sorting.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change
/// - Selected popular period changes (Right Now / Week / Month / All-Time)
final class PopularVideosFeedProvider
    extends $AsyncNotifierProvider<PopularVideosFeed, VideoFeedState> {
  /// Popular Videos feed provider - shows trending videos by recent engagement.
  ///
  /// Delegates video fetching to [VideosRepository.getPopularVideos], which
  /// implements a 3-tier fallback: Funnelcake REST API → NIP-50 sort:hot →
  /// client-side engagement sorting.
  ///
  /// Rebuilds when:
  /// - Pull to refresh
  /// - appReady gate becomes true
  /// - Content filter preferences change
  /// - Selected popular period changes (Right Now / Week / Month / All-Time)
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

String _$popularVideosFeedHash() => r'f7c6350218d72d21dbb860f1e9884978666de26b';

/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates video fetching to [VideosRepository.getPopularVideos], which
/// implements a 3-tier fallback: Funnelcake REST API → NIP-50 sort:hot →
/// client-side engagement sorting.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change
/// - Selected popular period changes (Right Now / Week / Month / All-Time)

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
