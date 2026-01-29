// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classic_vines_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ClassicVines feed provider - shows pre-2017 Vine archive sorted by loops
///
/// Uses REST API (Funnelcake) when available for comprehensive classic Vine data.
/// Falls back to Nostr discovery videos that have embedded loop stats (originalLoops > 0),
/// which includes imported classic Vines that have the loop count in their event tags.

@ProviderFor(ClassicVinesFeed)
const classicVinesFeedProvider = ClassicVinesFeedProvider._();

/// ClassicVines feed provider - shows pre-2017 Vine archive sorted by loops
///
/// Uses REST API (Funnelcake) when available for comprehensive classic Vine data.
/// Falls back to Nostr discovery videos that have embedded loop stats (originalLoops > 0),
/// which includes imported classic Vines that have the loop count in their event tags.
final class ClassicVinesFeedProvider
    extends $AsyncNotifierProvider<ClassicVinesFeed, VideoFeedState> {
  /// ClassicVines feed provider - shows pre-2017 Vine archive sorted by loops
  ///
  /// Uses REST API (Funnelcake) when available for comprehensive classic Vine data.
  /// Falls back to Nostr discovery videos that have embedded loop stats (originalLoops > 0),
  /// which includes imported classic Vines that have the loop count in their event tags.
  const ClassicVinesFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classicVinesFeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classicVinesFeedHash();

  @$internal
  @override
  ClassicVinesFeed create() => ClassicVinesFeed();
}

String _$classicVinesFeedHash() => r'ff2c7359c5ad536a87b84b101a50a8f0bea35d94';

/// ClassicVines feed provider - shows pre-2017 Vine archive sorted by loops
///
/// Uses REST API (Funnelcake) when available for comprehensive classic Vine data.
/// Falls back to Nostr discovery videos that have embedded loop stats (originalLoops > 0),
/// which includes imported classic Vines that have the loop count in their event tags.

abstract class _$ClassicVinesFeed extends $AsyncNotifier<VideoFeedState> {
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

/// Provider to check if classic vines feed is loading

@ProviderFor(classicVinesFeedLoading)
const classicVinesFeedLoadingProvider = ClassicVinesFeedLoadingProvider._();

/// Provider to check if classic vines feed is loading

final class ClassicVinesFeedLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if classic vines feed is loading
  const ClassicVinesFeedLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classicVinesFeedLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classicVinesFeedLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return classicVinesFeedLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$classicVinesFeedLoadingHash() =>
    r'8ab3ecc7147fc09d4f39d5d40c0b10a7d44ade81';

/// Provider to get current classic vines feed video count

@ProviderFor(classicVinesFeedCount)
const classicVinesFeedCountProvider = ClassicVinesFeedCountProvider._();

/// Provider to get current classic vines feed video count

final class ClassicVinesFeedCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Provider to get current classic vines feed video count
  const ClassicVinesFeedCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classicVinesFeedCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classicVinesFeedCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return classicVinesFeedCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$classicVinesFeedCountHash() =>
    r'b165c04f3d38d09dfaff91653d82300f248b73dc';

/// Provider to check if classic vines are available
///
/// Delegates to the centralized funnelcakeAvailableProvider.
/// Classic vines require Funnelcake REST API to be available.

@ProviderFor(classicVinesAvailable)
const classicVinesAvailableProvider = ClassicVinesAvailableProvider._();

/// Provider to check if classic vines are available
///
/// Delegates to the centralized funnelcakeAvailableProvider.
/// Classic vines require Funnelcake REST API to be available.

final class ClassicVinesAvailableProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Provider to check if classic vines are available
  ///
  /// Delegates to the centralized funnelcakeAvailableProvider.
  /// Classic vines require Funnelcake REST API to be available.
  const ClassicVinesAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classicVinesAvailableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classicVinesAvailableHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return classicVinesAvailable(ref);
  }
}

String _$classicVinesAvailableHash() =>
    r'39ee4ffc7ab9d5494577f0ef017908bc6103f394';

/// Provider for top classic Viners derived from classic videos
///
/// Aggregates videos by pubkey and sorts by total loop count

@ProviderFor(topClassicViners)
const topClassicVinersProvider = TopClassicVinersProvider._();

/// Provider for top classic Viners derived from classic videos
///
/// Aggregates videos by pubkey and sorts by total loop count

final class TopClassicVinersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ClassicViner>>,
          List<ClassicViner>,
          FutureOr<List<ClassicViner>>
        >
    with
        $FutureModifier<List<ClassicViner>>,
        $FutureProvider<List<ClassicViner>> {
  /// Provider for top classic Viners derived from classic videos
  ///
  /// Aggregates videos by pubkey and sorts by total loop count
  const TopClassicVinersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'topClassicVinersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$topClassicVinersHash();

  @$internal
  @override
  $FutureProviderElement<List<ClassicViner>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ClassicViner>> create(Ref ref) {
    return topClassicViners(ref);
  }
}

String _$topClassicVinersHash() => r'580ba7973d049a9db3ff40c2d3cd6dcc3d451adf';
