// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reactive profile provider backed by Drift's watchProfile stream.
///
/// On first access for a pubkey:
/// 1. Checks Drift cache — if missing, fires a background fetchFreshProfile
/// 2. Yields from the Drift watch stream, so any cache update (from fetch,
///    profile edit, or batch prefetch) automatically flows to consumers.
///
/// Consumers get `AsyncValue<UserProfile?>` — same API as the old
/// FutureProvider, so widget code changes are minimal.

@ProviderFor(userProfileReactive)
final userProfileReactiveProvider = UserProfileReactiveFamily._();

/// Reactive profile provider backed by Drift's watchProfile stream.
///
/// On first access for a pubkey:
/// 1. Checks Drift cache — if missing, fires a background fetchFreshProfile
/// 2. Yields from the Drift watch stream, so any cache update (from fetch,
///    profile edit, or batch prefetch) automatically flows to consumers.
///
/// Consumers get `AsyncValue<UserProfile?>` — same API as the old
/// FutureProvider, so widget code changes are minimal.

final class UserProfileReactiveProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProfile?>,
          UserProfile?,
          Stream<UserProfile?>
        >
    with $FutureModifier<UserProfile?>, $StreamProvider<UserProfile?> {
  /// Reactive profile provider backed by Drift's watchProfile stream.
  ///
  /// On first access for a pubkey:
  /// 1. Checks Drift cache — if missing, fires a background fetchFreshProfile
  /// 2. Yields from the Drift watch stream, so any cache update (from fetch,
  ///    profile edit, or batch prefetch) automatically flows to consumers.
  ///
  /// Consumers get `AsyncValue<UserProfile?>` — same API as the old
  /// FutureProvider, so widget code changes are minimal.
  UserProfileReactiveProvider._({
    required UserProfileReactiveFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userProfileReactiveProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userProfileReactiveHash();

  @override
  String toString() {
    return r'userProfileReactiveProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<UserProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<UserProfile?> create(Ref ref) {
    final argument = this.argument as String;
    return userProfileReactive(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfileReactiveProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userProfileReactiveHash() =>
    r'f0c15277edfd883bf7d28cb94b19822f01f94934';

/// Reactive profile provider backed by Drift's watchProfile stream.
///
/// On first access for a pubkey:
/// 1. Checks Drift cache — if missing, fires a background fetchFreshProfile
/// 2. Yields from the Drift watch stream, so any cache update (from fetch,
///    profile edit, or batch prefetch) automatically flows to consumers.
///
/// Consumers get `AsyncValue<UserProfile?>` — same API as the old
/// FutureProvider, so widget code changes are minimal.

final class UserProfileReactiveFamily extends $Family
    with $FunctionalFamilyOverride<Stream<UserProfile?>, String> {
  UserProfileReactiveFamily._()
    : super(
        retry: null,
        name: r'userProfileReactiveProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reactive profile provider backed by Drift's watchProfile stream.
  ///
  /// On first access for a pubkey:
  /// 1. Checks Drift cache — if missing, fires a background fetchFreshProfile
  /// 2. Yields from the Drift watch stream, so any cache update (from fetch,
  ///    profile edit, or batch prefetch) automatically flows to consumers.
  ///
  /// Consumers get `AsyncValue<UserProfile?>` — same API as the old
  /// FutureProvider, so widget code changes are minimal.

  UserProfileReactiveProvider call(String pubkey) =>
      UserProfileReactiveProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'userProfileReactiveProvider';
}

/// One-shot provider: returns cached profile or fetches fresh.
///
/// Use this when you need a single read (e.g., building a share sheet)
/// rather than a reactive stream.

@ProviderFor(fetchUserProfile)
final fetchUserProfileProvider = FetchUserProfileFamily._();

/// One-shot provider: returns cached profile or fetches fresh.
///
/// Use this when you need a single read (e.g., building a share sheet)
/// rather than a reactive stream.

final class FetchUserProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProfile?>,
          UserProfile?,
          FutureOr<UserProfile?>
        >
    with $FutureModifier<UserProfile?>, $FutureProvider<UserProfile?> {
  /// One-shot provider: returns cached profile or fetches fresh.
  ///
  /// Use this when you need a single read (e.g., building a share sheet)
  /// rather than a reactive stream.
  FetchUserProfileProvider._({
    required FetchUserProfileFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'fetchUserProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fetchUserProfileHash();

  @override
  String toString() {
    return r'fetchUserProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UserProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UserProfile?> create(Ref ref) {
    final argument = this.argument as String;
    return fetchUserProfile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FetchUserProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fetchUserProfileHash() => r'dfe728a31fbdb14c6466704f7688b6ee85091e2b';

/// One-shot provider: returns cached profile or fetches fresh.
///
/// Use this when you need a single read (e.g., building a share sheet)
/// rather than a reactive stream.

final class FetchUserProfileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UserProfile?>, String> {
  FetchUserProfileFamily._()
    : super(
        retry: null,
        name: r'fetchUserProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One-shot provider: returns cached profile or fetches fresh.
  ///
  /// Use this when you need a single read (e.g., building a share sheet)
  /// rather than a reactive stream.

  FetchUserProfileProvider call(String pubkey) =>
      FetchUserProfileProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'fetchUserProfileProvider';
}

/// Whether the account behind [pubkey] has requested NIP-62 deletion.
///
/// Backed by the durable `vanished_profiles` table, so a cold start resolves
/// without a network round trip, and it flips live when a fetch discovers a
/// new deletion. This — not the profile provider — drives the deleted-account
/// treatment in the inbox and the following bar.

@ProviderFor(profileVanished)
final profileVanishedProvider = ProfileVanishedFamily._();

/// Whether the account behind [pubkey] has requested NIP-62 deletion.
///
/// Backed by the durable `vanished_profiles` table, so a cold start resolves
/// without a network round trip, and it flips live when a fetch discovers a
/// new deletion. This — not the profile provider — drives the deleted-account
/// treatment in the inbox and the following bar.

final class ProfileVanishedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether the account behind [pubkey] has requested NIP-62 deletion.
  ///
  /// Backed by the durable `vanished_profiles` table, so a cold start resolves
  /// without a network round trip, and it flips live when a fetch discovers a
  /// new deletion. This — not the profile provider — drives the deleted-account
  /// treatment in the inbox and the following bar.
  ProfileVanishedProvider._({
    required ProfileVanishedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileVanishedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileVanishedHash();

  @override
  String toString() {
    return r'profileVanishedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    final argument = this.argument as String;
    return profileVanished(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileVanishedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileVanishedHash() => r'cb1f9c9ef27a29577e5299d468dc777a052a86b1';

/// Whether the account behind [pubkey] has requested NIP-62 deletion.
///
/// Backed by the durable `vanished_profiles` table, so a cold start resolves
/// without a network round trip, and it flips live when a fetch discovers a
/// new deletion. This — not the profile provider — drives the deleted-account
/// treatment in the inbox and the following bar.

final class ProfileVanishedFamily extends $Family
    with $FunctionalFamilyOverride<Stream<bool>, String> {
  ProfileVanishedFamily._()
    : super(
        retry: null,
        name: r'profileVanishedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether the account behind [pubkey] has requested NIP-62 deletion.
  ///
  /// Backed by the durable `vanished_profiles` table, so a cold start resolves
  /// without a network round trip, and it flips live when a fetch discovers a
  /// new deletion. This — not the profile provider — drives the deleted-account
  /// treatment in the inbox and the following bar.

  ProfileVanishedProvider call(String pubkey) =>
      ProfileVanishedProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'profileVanishedProvider';
}
