// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_events_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$videoEventsNostrServiceHash() =>
    r'28f9463512b1dd6bb87bbd332de86bbf9861c643';

/// Provider for NostrService instance (Video Events specific)
///
/// Copied from [videoEventsNostrService].
@ProviderFor(videoEventsNostrService)
final videoEventsNostrServiceProvider =
    AutoDisposeProvider<INostrService>.internal(
  videoEventsNostrService,
  name: r'videoEventsNostrServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$videoEventsNostrServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VideoEventsNostrServiceRef = AutoDisposeProviderRef<INostrService>;
String _$videoEventsSubscriptionManagerHash() =>
    r'de8a57af8aaa84ed4118824ab67fc5b044a31a01';

/// Provider for SubscriptionManager instance (Video Events specific)
///
/// Copied from [videoEventsSubscriptionManager].
@ProviderFor(videoEventsSubscriptionManager)
final videoEventsSubscriptionManagerProvider =
    AutoDisposeProvider<SubscriptionManager>.internal(
  videoEventsSubscriptionManager,
  name: r'videoEventsSubscriptionManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$videoEventsSubscriptionManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VideoEventsSubscriptionManagerRef
    = AutoDisposeProviderRef<SubscriptionManager>;
String _$videoEventsLoadingHash() =>
    r'1dd692805987ef7d470ad161a1e377aa6c8ef835';

/// Provider to check if video events are loading
///
/// Copied from [videoEventsLoading].
@ProviderFor(videoEventsLoading)
final videoEventsLoadingProvider = AutoDisposeProvider<bool>.internal(
  videoEventsLoading,
  name: r'videoEventsLoadingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$videoEventsLoadingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VideoEventsLoadingRef = AutoDisposeProviderRef<bool>;
String _$videoEventCountHash() => r'e7c599f34b92ca4d88daf33c3164524164f8c527';

/// Provider to get video event count
///
/// Copied from [videoEventCount].
@ProviderFor(videoEventCount)
final videoEventCountProvider = AutoDisposeProvider<int>.internal(
  videoEventCount,
  name: r'videoEventCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$videoEventCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VideoEventCountRef = AutoDisposeProviderRef<int>;
String _$videoEventsHash() => r'd78867ba698328aa6cc924a9c0c4b31c904698d5';

/// Stream provider for video events from Nostr
///
/// Copied from [VideoEvents].
@ProviderFor(VideoEvents)
final videoEventsProvider =
    AutoDisposeStreamNotifierProvider<VideoEvents, List<VideoEvent>>.internal(
  VideoEvents.new,
  name: r'videoEventsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$videoEventsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VideoEvents = AutoDisposeStreamNotifier<List<VideoEvent>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
