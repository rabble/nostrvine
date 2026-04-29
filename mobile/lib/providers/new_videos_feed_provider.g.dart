// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_videos_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// New Videos feed provider - shows newest videos first.
///
/// Delegates video fetching to [VideosRepository.getNewVideos] so the Explore
/// New Videos tab does not share the popular/trending source.

@ProviderFor(NewVideosFeed)
const newVideosFeedProvider = NewVideosFeedProvider._();

/// New Videos feed provider - shows newest videos first.
///
/// Delegates video fetching to [VideosRepository.getNewVideos] so the Explore
/// New Videos tab does not share the popular/trending source.
final class NewVideosFeedProvider
    extends $AsyncNotifierProvider<NewVideosFeed, VideoFeedState> {
  /// New Videos feed provider - shows newest videos first.
  ///
  /// Delegates video fetching to [VideosRepository.getNewVideos] so the Explore
  /// New Videos tab does not share the popular/trending source.
  const NewVideosFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'newVideosFeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$newVideosFeedHash();

  @$internal
  @override
  NewVideosFeed create() => NewVideosFeed();
}

String _$newVideosFeedHash() => r'5a0b3c8fa9079c035a5b76d0e421dcb7aa21e13f';

/// New Videos feed provider - shows newest videos first.
///
/// Delegates video fetching to [VideosRepository.getNewVideos] so the Explore
/// New Videos tab does not share the popular/trending source.

abstract class _$NewVideosFeed extends $AsyncNotifier<VideoFeedState> {
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
