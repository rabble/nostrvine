// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hashtag_feed_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Hashtag feed provider - shows videos with a specific hashtag
///
/// Rebuilds when:
/// - Route changes (different hashtag)
/// - User pulls to refresh
/// - VideoEventService updates with new hashtag videos

@ProviderFor(HashtagFeed)
const hashtagFeedProvider = HashtagFeedProvider._();

/// Hashtag feed provider - shows videos with a specific hashtag
///
/// Rebuilds when:
/// - Route changes (different hashtag)
/// - User pulls to refresh
/// - VideoEventService updates with new hashtag videos
final class HashtagFeedProvider
    extends $AsyncNotifierProvider<HashtagFeed, VideoFeedState> {
  /// Hashtag feed provider - shows videos with a specific hashtag
  ///
  /// Rebuilds when:
  /// - Route changes (different hashtag)
  /// - User pulls to refresh
  /// - VideoEventService updates with new hashtag videos
  const HashtagFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hashtagFeedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hashtagFeedHash();

  @$internal
  @override
  HashtagFeed create() => HashtagFeed();
}

String _$hashtagFeedHash() => r'9663c0244ecb4b526e7b54a86b73e71a6ed546de';

/// Hashtag feed provider - shows videos with a specific hashtag
///
/// Rebuilds when:
/// - Route changes (different hashtag)
/// - User pulls to refresh
/// - VideoEventService updates with new hashtag videos

abstract class _$HashtagFeed extends $AsyncNotifier<VideoFeedState> {
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
