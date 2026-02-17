// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popular_videos_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Popular Videos feed provider - shows trending videos by recent engagement
///
/// Strategy: Try Funnelcake REST API first (sort=trending) for current popularity,
/// fall back to Nostr subscription with local engagement sorting if REST API is unavailable.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true

@ProviderFor(PopularVideosFeed)
const popularVideosFeedProvider = PopularVideosFeedProvider._();

/// Popular Videos feed provider - shows trending videos by recent engagement
///
/// Strategy: Try Funnelcake REST API first (sort=trending) for current popularity,
/// fall back to Nostr subscription with local engagement sorting if REST API is unavailable.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
final class PopularVideosFeedProvider
    extends $AsyncNotifierProvider<PopularVideosFeed, VideoFeedState> {
  /// Popular Videos feed provider - shows trending videos by recent engagement
  ///
  /// Strategy: Try Funnelcake REST API first (sort=trending) for current popularity,
  /// fall back to Nostr subscription with local engagement sorting if REST API is unavailable.
  ///
  /// Rebuilds when:
  /// - Pull to refresh
  /// - appReady gate becomes true
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

String _$popularVideosFeedHash() => r'b6f8f5ad74bdcbfcbdeb21cf5581b3deb3828236';

/// Popular Videos feed provider - shows trending videos by recent engagement
///
/// Strategy: Try Funnelcake REST API first (sort=trending) for current popularity,
/// fall back to Nostr subscription with local engagement sorting if REST API is unavailable.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true

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
