// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_reply_context_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider holding the active video reply context.
///
/// When non-null, the video editor flow should skip the metadata
/// screen and publish as a comment via [VideoCommentPublishService].

@ProviderFor(VideoReplyContextNotifier)
const videoReplyContextProvider = VideoReplyContextNotifierProvider._();

/// Provider holding the active video reply context.
///
/// When non-null, the video editor flow should skip the metadata
/// screen and publish as a comment via [VideoCommentPublishService].
final class VideoReplyContextNotifierProvider
    extends $NotifierProvider<VideoReplyContextNotifier, VideoReplyContext?> {
  /// Provider holding the active video reply context.
  ///
  /// When non-null, the video editor flow should skip the metadata
  /// screen and publish as a comment via [VideoCommentPublishService].
  const VideoReplyContextNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoReplyContextProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoReplyContextNotifierHash();

  @$internal
  @override
  VideoReplyContextNotifier create() => VideoReplyContextNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoReplyContext? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoReplyContext?>(value),
    );
  }
}

String _$videoReplyContextNotifierHash() =>
    r'32ddfe3b08a6d3fc6f8a4f126332115a9353a695';

/// Provider holding the active video reply context.
///
/// When non-null, the video editor flow should skip the metadata
/// screen and publish as a comment via [VideoCommentPublishService].

abstract class _$VideoReplyContextNotifier
    extends $Notifier<VideoReplyContext?> {
  VideoReplyContext? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<VideoReplyContext?, VideoReplyContext?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VideoReplyContext?, VideoReplyContext?>,
              VideoReplyContext?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
