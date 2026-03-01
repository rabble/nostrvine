// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_comment_publish_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for [VideoCommentPublishService].
///
/// Composes [BlossomUploadService] and [CommentsRepository]
/// to enable uploading and posting video comments.

@ProviderFor(videoCommentPublishService)
const videoCommentPublishServiceProvider =
    VideoCommentPublishServiceProvider._();

/// Provider for [VideoCommentPublishService].
///
/// Composes [BlossomUploadService] and [CommentsRepository]
/// to enable uploading and posting video comments.

final class VideoCommentPublishServiceProvider
    extends
        $FunctionalProvider<
          VideoCommentPublishService,
          VideoCommentPublishService,
          VideoCommentPublishService
        >
    with $Provider<VideoCommentPublishService> {
  /// Provider for [VideoCommentPublishService].
  ///
  /// Composes [BlossomUploadService] and [CommentsRepository]
  /// to enable uploading and posting video comments.
  const VideoCommentPublishServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoCommentPublishServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoCommentPublishServiceHash();

  @$internal
  @override
  $ProviderElement<VideoCommentPublishService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoCommentPublishService create(Ref ref) {
    return videoCommentPublishService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoCommentPublishService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoCommentPublishService>(value),
    );
  }
}

String _$videoCommentPublishServiceHash() =>
    r'a998759e79e19701499d16440b944fb2994496cf';
