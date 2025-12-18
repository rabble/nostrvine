// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream provider for current user's following list (reactive)

@ProviderFor(followingList)
const followingListProvider = FollowingListProvider._();

/// Stream provider for current user's following list (reactive)

final class FollowingListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          Stream<List<String>>
        >
    with $FutureModifier<List<String>>, $StreamProvider<List<String>> {
  /// Stream provider for current user's following list (reactive)
  const FollowingListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'followingListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$followingListHash();

  @$internal
  @override
  $StreamProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<String>> create(Ref ref) {
    return followingList(ref);
  }
}

String _$followingListHash() => r'21ee66296301f7c8f457b26f166e9a7fbcb58f53';

/// Family provider to check if current user is following a specific pubkey
/// This is reactive - listens to repository's followingStream for updates

@ProviderFor(isFollowing)
const isFollowingProvider = IsFollowingFamily._();

/// Family provider to check if current user is following a specific pubkey
/// This is reactive - listens to repository's followingStream for updates

final class IsFollowingProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Family provider to check if current user is following a specific pubkey
  /// This is reactive - listens to repository's followingStream for updates
  const IsFollowingProvider._({
    required IsFollowingFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isFollowingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isFollowingHash();

  @override
  String toString() {
    return r'isFollowingProvider'
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
    return isFollowing(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IsFollowingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isFollowingHash() => r'3bc47c82260d678d3cc5b83123d57038e39db19f';

/// Family provider to check if current user is following a specific pubkey
/// This is reactive - listens to repository's followingStream for updates

final class IsFollowingFamily extends $Family
    with $FunctionalFamilyOverride<Stream<bool>, String> {
  const IsFollowingFamily._()
    : super(
        retry: null,
        name: r'isFollowingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Family provider to check if current user is following a specific pubkey
  /// This is reactive - listens to repository's followingStream for updates

  IsFollowingProvider call(String pubkey) =>
      IsFollowingProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'isFollowingProvider';
}

/// Notifier for managing follow state and operations
/// - Checks if current user is following a pubkey
/// - Tracks which pubkeys have active follow/unfollow operations
/// - Provides follow/unfollow/toggle actions
///
/// Returns empty set and no-ops when not authenticated.

@ProviderFor(FollowOperations)
const followOperationsProvider = FollowOperationsProvider._();

/// Notifier for managing follow state and operations
/// - Checks if current user is following a pubkey
/// - Tracks which pubkeys have active follow/unfollow operations
/// - Provides follow/unfollow/toggle actions
///
/// Returns empty set and no-ops when not authenticated.
final class FollowOperationsProvider
    extends $NotifierProvider<FollowOperations, Set<String>> {
  /// Notifier for managing follow state and operations
  /// - Checks if current user is following a pubkey
  /// - Tracks which pubkeys have active follow/unfollow operations
  /// - Provides follow/unfollow/toggle actions
  ///
  /// Returns empty set and no-ops when not authenticated.
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

String _$followOperationsHash() => r'f67be3bb38fcf874e336cc9c9bda1e91fcc67191';

/// Notifier for managing follow state and operations
/// - Checks if current user is following a pubkey
/// - Tracks which pubkeys have active follow/unfollow operations
/// - Provides follow/unfollow/toggle actions
///
/// Returns empty set and no-ops when not authenticated.

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
