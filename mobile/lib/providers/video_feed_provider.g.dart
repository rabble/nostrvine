// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Simple discovery video feed provider

@ProviderFor(VideoFeed)
const videoFeedProvider = VideoFeedProvider._();

/// Simple discovery video feed provider
final class VideoFeedProvider
    extends $AsyncNotifierProvider<VideoFeed, VideoFeedState> {
  /// Simple discovery video feed provider
  const VideoFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoFeedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoFeedHash();

  @$internal
  @override
  VideoFeed create() => VideoFeed();
}

String _$videoFeedHash() => r'f7a25661530d5a78223ac9f6bb897ab9d2b81f90';

/// Simple discovery video feed provider

abstract class _$VideoFeed extends $AsyncNotifier<VideoFeedState> {
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

/// Provider to check if video feed is loading

@ProviderFor(videoFeedLoading)
const videoFeedLoadingProvider = VideoFeedLoadingProvider._();

/// Provider to check if video feed is loading

final class VideoFeedLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if video feed is loading
  const VideoFeedLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoFeedLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoFeedLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return videoFeedLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$videoFeedLoadingHash() => r'055850405fbf52cb95fa8a6d62b431fc5b5aed2a';

/// Provider to get current video count

@ProviderFor(videoFeedCount)
const videoFeedCountProvider = VideoFeedCountProvider._();

/// Provider to get current video count

final class VideoFeedCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Provider to get current video count
  const VideoFeedCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoFeedCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoFeedCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return videoFeedCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$videoFeedCountHash() => r'de3d7d4c6f880e868a4a0c490b3c4df125040195';

/// Provider to check if we have videos

@ProviderFor(hasVideos)
const hasVideosProvider = HasVideosProvider._();

/// Provider to check if we have videos

final class HasVideosProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if we have videos
  const HasVideosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasVideosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasVideosHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hasVideos(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasVideosHash() => r'2780fade78b3238a1979632f42151a3400b482b7';
