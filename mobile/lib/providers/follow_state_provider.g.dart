// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

String _$isFollowingUserHash() => r'bfeefbd766f64e8e9fb6516dd0293092d634cc6b';

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

/// Notifier for managing follow operations in progress
/// Tracks which pubkeys have active follow/unfollow operations

@ProviderFor(FollowOperations)
const followOperationsProvider = FollowOperationsProvider._();

/// Notifier for managing follow operations in progress
/// Tracks which pubkeys have active follow/unfollow operations
final class FollowOperationsProvider
    extends $NotifierProvider<FollowOperations, Set<String>> {
  /// Notifier for managing follow operations in progress
  /// Tracks which pubkeys have active follow/unfollow operations
  const FollowOperationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'followOperationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$followOperationsHash();

  @$internal
  @override
  FollowOperations create() => FollowOperations();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$followOperationsHash() => r'84209290fd4001cc47d25b48b43be3fa1b64822b';

/// Notifier for managing follow operations in progress
/// Tracks which pubkeys have active follow/unfollow operations

abstract class _$FollowOperations extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
