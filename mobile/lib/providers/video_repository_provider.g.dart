// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for VideoRepository instance.
///
/// Creates a VideoRepository as the single source of truth for video storage.
/// Uses keepAlive to ensure the repository persists across the app lifecycle.
///
/// The repository handles:
/// - Write-time deduplication with normalized IDs
/// - Subscription membership tracking
/// - Hashtag and author indexing

@ProviderFor(videoRepository)
const videoRepositoryProvider = VideoRepositoryProvider._();

/// Provider for VideoRepository instance.
///
/// Creates a VideoRepository as the single source of truth for video storage.
/// Uses keepAlive to ensure the repository persists across the app lifecycle.
///
/// The repository handles:
/// - Write-time deduplication with normalized IDs
/// - Subscription membership tracking
/// - Hashtag and author indexing

final class VideoRepositoryProvider
    extends
        $FunctionalProvider<VideoRepository, VideoRepository, VideoRepository>
    with $Provider<VideoRepository> {
  /// Provider for VideoRepository instance.
  ///
  /// Creates a VideoRepository as the single source of truth for video storage.
  /// Uses keepAlive to ensure the repository persists across the app lifecycle.
  ///
  /// The repository handles:
  /// - Write-time deduplication with normalized IDs
  /// - Subscription membership tracking
  /// - Hashtag and author indexing
  const VideoRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoRepositoryHash();

  @$internal
  @override
  $ProviderElement<VideoRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VideoRepository create(Ref ref) {
    return videoRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoRepository>(value),
    );
  }
}

String _$videoRepositoryHash() => r'b61b0c72401b24d23484f8dc8b88c1445d510848';
