// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'following_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for fetching and managing a user's following list
/// - For current user: uses SocialRepository (reactive updates)
/// - For other users: fetches from Nostr relays

@ProviderFor(FollowingListNotifier)
const followingListProvider = FollowingListNotifierFamily._();

/// Provider for fetching and managing a user's following list
/// - For current user: uses SocialRepository (reactive updates)
/// - For other users: fetches from Nostr relays
final class FollowingListNotifierProvider
    extends $AsyncNotifierProvider<FollowingListNotifier, List<String>> {
  /// Provider for fetching and managing a user's following list
  /// - For current user: uses SocialRepository (reactive updates)
  /// - For other users: fetches from Nostr relays
  const FollowingListNotifierProvider._({
    required FollowingListNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'followingListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$followingListNotifierHash();

  @override
  String toString() {
    return r'followingListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FollowingListNotifier create() => FollowingListNotifier();

  @override
  bool operator ==(Object other) {
    return other is FollowingListNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$followingListNotifierHash() =>
    r'b7aac0bf8a5488e50acef86dfbec1ac6727f78d0';

/// Provider for fetching and managing a user's following list
/// - For current user: uses SocialRepository (reactive updates)
/// - For other users: fetches from Nostr relays

final class FollowingListNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          FollowingListNotifier,
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>,
          String
        > {
  const FollowingListNotifierFamily._()
    : super(
        retry: null,
        name: r'followingListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for fetching and managing a user's following list
  /// - For current user: uses SocialRepository (reactive updates)
  /// - For other users: fetches from Nostr relays

  FollowingListNotifierProvider call(String pubkey) =>
      FollowingListNotifierProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'followingListProvider';
}

/// Provider for fetching and managing a user's following list
/// - For current user: uses SocialRepository (reactive updates)
/// - For other users: fetches from Nostr relays

abstract class _$FollowingListNotifier extends $AsyncNotifier<List<String>> {
  late final _$args = ref.$arg as String;
  String get pubkey => _$args;

  FutureOr<List<String>> build(String pubkey);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<List<String>>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<String>>, List<String>>,
              AsyncValue<List<String>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Stream provider for current user's following list (reactive)
/// Use this when you only need the current user's following

@ProviderFor(currentUserFollowingList)
const currentUserFollowingListProvider = CurrentUserFollowingListProvider._();

/// Stream provider for current user's following list (reactive)
/// Use this when you only need the current user's following

final class CurrentUserFollowingListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          Stream<List<String>>
        >
    with $FutureModifier<List<String>>, $StreamProvider<List<String>> {
  /// Stream provider for current user's following list (reactive)
  /// Use this when you only need the current user's following
  const CurrentUserFollowingListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserFollowingListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserFollowingListHash();

  @$internal
  @override
  $StreamProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<String>> create(Ref ref) {
    return currentUserFollowingList(ref);
  }
}

String _$currentUserFollowingListHash() =>
    r'600318f6367c10f958d29f88b4836e70aa103ded';

/// Simple provider to check if currently following a specific pubkey
/// Uses the SocialRepository as source of truth

@ProviderFor(isFollowingUser)
const isFollowingUserProvider = IsFollowingUserFamily._();

/// Simple provider to check if currently following a specific pubkey
/// Uses the SocialRepository as source of truth

final class IsFollowingUserProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Simple provider to check if currently following a specific pubkey
  /// Uses the SocialRepository as source of truth
  const IsFollowingUserProvider._({
    required IsFollowingUserFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isFollowingUserProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isFollowingUserHash();

  @override
  String toString() {
    return r'isFollowingUserProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return isFollowingUser(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsFollowingUserProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isFollowingUserHash() => r'7e60a496538cf1357de9b7c5c9fe1c1e1f3fc94b';

/// Simple provider to check if currently following a specific pubkey
/// Uses the SocialRepository as source of truth

final class IsFollowingUserFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  const IsFollowingUserFamily._()
    : super(
        retry: null,
        name: r'isFollowingUserProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Simple provider to check if currently following a specific pubkey
  /// Uses the SocialRepository as source of truth

  IsFollowingUserProvider call(String pubkey) =>
      IsFollowingUserProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'isFollowingUserProvider';
}
