// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$curationServiceHash() => r'0fa3b3c8551452588d73ef3921d1f6bf87f2c3a8';

/// Provider for CurationService instance
///
/// Copied from [curationService].
@ProviderFor(curationService)
final curationServiceProvider = AutoDisposeProvider<CurationService>.internal(
  curationService,
  name: r'curationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$curationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurationServiceRef = AutoDisposeProviderRef<CurationService>;
String _$curationLoadingHash() => r'fc590d6955df325c10450e697501f0861481b863';

/// Provider to check if curation is loading
///
/// Copied from [curationLoading].
@ProviderFor(curationLoading)
final curationLoadingProvider = AutoDisposeProvider<bool>.internal(
  curationLoading,
  name: r'curationLoadingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$curationLoadingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurationLoadingRef = AutoDisposeProviderRef<bool>;
String _$editorsPicksHash() => r'1811cb42f820d8cdaa7634731d0106bb573fb233';

/// Provider to get editor's picks
///
/// Copied from [editorsPicks].
@ProviderFor(editorsPicks)
final editorsPicksProvider = AutoDisposeProvider<List<VideoEvent>>.internal(
  editorsPicks,
  name: r'editorsPicksProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$editorsPicksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EditorsPicksRef = AutoDisposeProviderRef<List<VideoEvent>>;
String _$trendingVideosHash() => r'e101adbbcf936fc50824d0afdc1e6a403f296fc2';

/// Provider to get trending videos
///
/// Copied from [trendingVideos].
@ProviderFor(trendingVideos)
final trendingVideosProvider = AutoDisposeProvider<List<VideoEvent>>.internal(
  trendingVideos,
  name: r'trendingVideosProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$trendingVideosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TrendingVideosRef = AutoDisposeProviderRef<List<VideoEvent>>;
String _$featuredVideosHash() => r'36f75bcbb02da3997c2a9fc0425b7f5aecc42b6c';

/// Provider to get featured videos
///
/// Copied from [featuredVideos].
@ProviderFor(featuredVideos)
final featuredVideosProvider = AutoDisposeProvider<List<VideoEvent>>.internal(
  featuredVideos,
  name: r'featuredVideosProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$featuredVideosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FeaturedVideosRef = AutoDisposeProviderRef<List<VideoEvent>>;
String _$curationHash() => r'01ae8753238c7a23a269ca862e23bf0d11ece4c2';

/// Main curation provider that manages curated content sets
///
/// Copied from [Curation].
@ProviderFor(Curation)
final curationProvider =
    AutoDisposeNotifierProvider<Curation, CurationState>.internal(
  Curation.new,
  name: r'curationProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$curationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Curation = AutoDisposeNotifier<CurationState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
