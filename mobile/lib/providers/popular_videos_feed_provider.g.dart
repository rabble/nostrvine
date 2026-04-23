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

String _$popularVideosFeedHash() => r'722f41829a5d6ba75f3f04a3882686011e1c67d6';

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
