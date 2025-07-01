// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$nostrServiceHash() => r'cd561ebed06aa0e738e1dc69aea8e80e3ecb3401';

/// See also [nostrService].
@ProviderFor(nostrService)
final nostrServiceProvider = AutoDisposeProvider<INostrService>.internal(
  nostrService,
  name: r'nostrServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$nostrServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NostrServiceRef = AutoDisposeProviderRef<INostrService>;
String _$authServiceHash() => r'df3357d0998e3ba237a3a9a07d1c3bd39258a284';

/// See also [authService].
@ProviderFor(authService)
final authServiceProvider = AutoDisposeProvider<AuthService>.internal(
  authService,
  name: r'authServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthServiceRef = AutoDisposeProviderRef<AuthService>;
String _$subscriptionManagerHash() =>
    r'058bbe054d59bc11afc47562f88aee361efe0a50';

/// See also [subscriptionManager].
@ProviderFor(subscriptionManager)
final subscriptionManagerProvider =
    AutoDisposeProvider<SubscriptionManager>.internal(
  subscriptionManager,
  name: r'subscriptionManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$subscriptionManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SubscriptionManagerRef = AutoDisposeProviderRef<SubscriptionManager>;
String _$socialHash() => r'54b06ad2269375f4233904318584730d4e92b53f';

/// See also [Social].
@ProviderFor(Social)
final socialProvider =
    AutoDisposeNotifierProvider<Social, SocialState>.internal(
  Social.new,
  name: r'socialProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$socialHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Social = AutoDisposeNotifier<SocialState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
