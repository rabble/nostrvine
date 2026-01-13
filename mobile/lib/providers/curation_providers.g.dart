// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for analytics API service

@ProviderFor(analyticsApiService)
const analyticsApiServiceProvider = AnalyticsApiServiceProvider._();

/// Provider for analytics API service

final class AnalyticsApiServiceProvider
    extends
        $FunctionalProvider<
          AnalyticsApiService,
          AnalyticsApiService,
          AnalyticsApiService
        >
    with $Provider<AnalyticsApiService> {
  /// Provider for analytics API service
  const AnalyticsApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsApiServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsApiServiceHash();

  @$internal
  @override
  $ProviderElement<AnalyticsApiService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AnalyticsApiService create(Ref ref) {
    return analyticsApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyticsApiService>(value),
    );
  }
}

String _$analyticsApiServiceHash() =>
    r'b47808c5318ce0b2f956bcd4b6f290e4dcf48846';

/// Main curation provider that manages curated content sets
/// keepAlive ensures provider persists across tab navigation

@ProviderFor(Curation)
const curationProvider = CurationProvider._();

/// Main curation provider that manages curated content sets
/// keepAlive ensures provider persists across tab navigation
final class CurationProvider
    extends $NotifierProvider<Curation, CurationState> {
  /// Main curation provider that manages curated content sets
  /// keepAlive ensures provider persists across tab navigation
  const CurationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curationHash();

  @$internal
  @override
  Curation create() => Curation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurationState>(value),
    );
  }
}

String _$curationHash() => r'ac57ca4fa72232ccf104c8b4739ec94c91aaa3d8';

/// Main curation provider that manages curated content sets
/// keepAlive ensures provider persists across tab navigation

abstract class _$Curation extends $Notifier<CurationState> {
  CurationState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CurationState, CurationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CurationState, CurationState>,
              CurationState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider to check if curation is loading

@ProviderFor(curationLoading)
const curationLoadingProvider = CurationLoadingProvider._();

/// Provider to check if curation is loading

final class CurationLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if curation is loading
  const CurationLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curationLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curationLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return curationLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$curationLoadingHash() => r'e1a04d9f8d90870d340665613c0938b356085039';

/// Provider to get editor's picks

@ProviderFor(editorsPicks)
const editorsPicksProvider = EditorsPicksProvider._();

/// Provider to get editor's picks

final class EditorsPicksProvider
    extends
        $FunctionalProvider<
          List<VideoEvent>,
          List<VideoEvent>,
          List<VideoEvent>
        >
    with $Provider<List<VideoEvent>> {
  /// Provider to get editor's picks
  const EditorsPicksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editorsPicksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editorsPicksHash();

  @$internal
  @override
  $ProviderElement<List<VideoEvent>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<VideoEvent> create(Ref ref) {
    return editorsPicks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<VideoEvent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<VideoEvent>>(value),
    );
  }
}

String _$editorsPicksHash() => r'47f6f4c73a8e2f6f8aafa718986c063feb530d08';

/// Provider for analytics-based trending videos

@ProviderFor(AnalyticsTrending)
const analyticsTrendingProvider = AnalyticsTrendingProvider._();

/// Provider for analytics-based trending videos
final class AnalyticsTrendingProvider
    extends $NotifierProvider<AnalyticsTrending, List<VideoEvent>> {
  /// Provider for analytics-based trending videos
  const AnalyticsTrendingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsTrendingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsTrendingHash();

  @$internal
  @override
  AnalyticsTrending create() => AnalyticsTrending();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<VideoEvent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<VideoEvent>>(value),
    );
  }
}

String _$analyticsTrendingHash() => r'6bf4dd9f6cd1c64c157f7c5733909211e6729a41';

/// Provider for analytics-based trending videos

abstract class _$AnalyticsTrending extends $Notifier<List<VideoEvent>> {
  List<VideoEvent> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<VideoEvent>, List<VideoEvent>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<VideoEvent>, List<VideoEvent>>,
              List<VideoEvent>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for analytics-based popular videos

@ProviderFor(AnalyticsPopular)
const analyticsPopularProvider = AnalyticsPopularProvider._();

/// Provider for analytics-based popular videos
final class AnalyticsPopularProvider
    extends $NotifierProvider<AnalyticsPopular, List<VideoEvent>> {
  /// Provider for analytics-based popular videos
  const AnalyticsPopularProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsPopularProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsPopularHash();

  @$internal
  @override
  AnalyticsPopular create() => AnalyticsPopular();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<VideoEvent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<VideoEvent>>(value),
    );
  }
}

String _$analyticsPopularHash() => r'3d9025ad3973f20185d45e07fe90f89143edbab6';

/// Provider for analytics-based popular videos

abstract class _$AnalyticsPopular extends $Notifier<List<VideoEvent>> {
  List<VideoEvent> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<VideoEvent>, List<VideoEvent>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<VideoEvent>, List<VideoEvent>>,
              List<VideoEvent>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for trending hashtags

@ProviderFor(TrendingHashtags)
const trendingHashtagsProvider = TrendingHashtagsProvider._();

/// Provider for trending hashtags
final class TrendingHashtagsProvider
    extends $NotifierProvider<TrendingHashtags, List<TrendingHashtag>> {
  /// Provider for trending hashtags
  const TrendingHashtagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trendingHashtagsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trendingHashtagsHash();

  @$internal
  @override
  TrendingHashtags create() => TrendingHashtags();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TrendingHashtag> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TrendingHashtag>>(value),
    );
  }
}

String _$trendingHashtagsHash() => r'f0f850462be2912bc79cc132077c1a026272d1ba';

/// Provider for trending hashtags

abstract class _$TrendingHashtags extends $Notifier<List<TrendingHashtag>> {
  List<TrendingHashtag> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<TrendingHashtag>, List<TrendingHashtag>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<TrendingHashtag>, List<TrendingHashtag>>,
              List<TrendingHashtag>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
