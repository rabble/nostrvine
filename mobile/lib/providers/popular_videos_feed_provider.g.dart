// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popular_videos_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates video fetching to [VideosRepository.getPopularVideos] with the
/// selected native/classic variant.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change

@ProviderFor(PopularVideosFeed)
final popularVideosFeedProvider = PopularVideosFeedProvider._();

/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates video fetching to [VideosRepository.getPopularVideos] with the
/// selected native/classic variant.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change
final class PopularVideosFeedProvider
    extends $AsyncNotifierProvider<PopularVideosFeed, VideoFeedState> {
  /// Popular Videos feed provider - shows trending videos by recent engagement.
  ///
  /// Delegates video fetching to [VideosRepository.getPopularVideos] with the
  /// selected native/classic variant.
  ///
  /// Rebuilds when:
  /// - Pull to refresh
  /// - appReady gate becomes true
  /// - Content filter preferences change
  PopularVideosFeedProvider._()
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

String _$popularVideosFeedHash() => r'78744d8b8cc02dd4a4f03d53c9bd58421e565c53';

/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates video fetching to [VideosRepository.getPopularVideos] with the
/// selected native/classic variant.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change

abstract class _$PopularVideosFeed extends $AsyncNotifier<VideoFeedState> {
  FutureOr<VideoFeedState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<VideoFeedState>, VideoFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideoFeedState>, VideoFeedState>,
              AsyncValue<VideoFeedState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
