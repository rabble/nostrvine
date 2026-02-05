// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'openvine_media_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider exposing the media cache singleton for dependency injection.
///
/// Use this in Riverpod contexts for testability - can be overridden in tests.
/// The underlying singleton is initialized in main.dart before Riverpod.

@ProviderFor(mediaCache)
const mediaCacheProvider = MediaCacheProvider._();

/// Provider exposing the media cache singleton for dependency injection.
///
/// Use this in Riverpod contexts for testability - can be overridden in tests.
/// The underlying singleton is initialized in main.dart before Riverpod.

final class MediaCacheProvider
    extends
        $FunctionalProvider<
          MediaCacheManager,
          MediaCacheManager,
          MediaCacheManager
        >
    with $Provider<MediaCacheManager> {
  /// Provider exposing the media cache singleton for dependency injection.
  ///
  /// Use this in Riverpod contexts for testability - can be overridden in tests.
  /// The underlying singleton is initialized in main.dart before Riverpod.
  const MediaCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaCacheHash();

  @$internal
  @override
  $ProviderElement<MediaCacheManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MediaCacheManager create(Ref ref) {
    return mediaCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaCacheManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaCacheManager>(value),
    );
  }
}

String _$mediaCacheHash() => r'bccfc594cbc77f2a8282367e1c46f974c023dc60';
