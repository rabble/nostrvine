// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_mode_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$feedModeNotifierHash() => r'0ca607e8db828ae1d61458f76967212f98059d5f';

/// Provider for managing the current feed mode
///
/// Copied from [FeedModeNotifier].
@ProviderFor(FeedModeNotifier)
final feedModeNotifierProvider =
    AutoDisposeNotifierProvider<FeedModeNotifier, FeedMode>.internal(
  FeedModeNotifier.new,
  name: r'feedModeNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$feedModeNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FeedModeNotifier = AutoDisposeNotifier<FeedMode>;
String _$feedContextHash() => r'8f5ccf33398ba9030b662d8e1be5327d10424344';

/// Provider for managing feed context (hashtag or pubkey)
///
/// Copied from [FeedContext].
@ProviderFor(FeedContext)
final feedContextProvider =
    AutoDisposeNotifierProvider<FeedContext, String?>.internal(
  FeedContext.new,
  name: r'feedContextProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$feedContextHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FeedContext = AutoDisposeNotifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
