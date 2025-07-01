// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_providers.dart';

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
String _$userProfilesHash() => r'0fbe7f7404bab9e1af0b252eff2a16b9315f419c';

/// See also [UserProfiles].
@ProviderFor(UserProfiles)
final userProfilesProvider =
    AutoDisposeNotifierProvider<UserProfiles, UserProfileState>.internal(
  UserProfiles.new,
  name: r'userProfilesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userProfilesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserProfiles = AutoDisposeNotifier<UserProfileState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
