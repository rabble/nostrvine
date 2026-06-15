// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app-wide [FeedRepository].
///
/// keepAlive so the fullscreen feed it backs is decoupled from the lifetime of
/// whichever widget opened the route — the core fix in issue #3383.

@ProviderFor(feedRepository)
const feedRepositoryProvider = FeedRepositoryProvider._();

/// The app-wide [FeedRepository].
///
/// keepAlive so the fullscreen feed it backs is decoupled from the lifetime of
/// whichever widget opened the route — the core fix in issue #3383.

final class FeedRepositoryProvider
    extends $FunctionalProvider<FeedRepository, FeedRepository, FeedRepository>
    with $Provider<FeedRepository> {
  /// The app-wide [FeedRepository].
  ///
  /// keepAlive so the fullscreen feed it backs is decoupled from the lifetime of
  /// whichever widget opened the route — the core fix in issue #3383.
  const FeedRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedRepositoryHash();

  @$internal
  @override
  $ProviderElement<FeedRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FeedRepository create(Ref ref) {
    return feedRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeedRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeedRepository>(value),
    );
  }
}

String _$feedRepositoryHash() => r'8eaba5d7e17e5ba3c8e6c44c3ad34c22ccc29a6c';
