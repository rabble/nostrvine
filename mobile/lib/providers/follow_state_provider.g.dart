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

String _$followingListHash() => r'f3a25ef6e384ce45eafc96285bea4731728a7f3d';

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

String _$isFollowingHash() => r'a0fdc331c68e7535dcd9fe076b2b836e3c6d4513';

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
/// Operations become no-ops when not authenticated (handled by repository).

@ProviderFor(FollowOperations)
const followOperationsProvider = FollowOperationsProvider._();

/// Notifier for managing follow state and operations
/// - Checks if current user is following a pubkey
/// - Tracks which pubkeys have active follow/unfollow operations
/// - Provides follow/unfollow/toggle actions
///
/// Operations become no-ops when not authenticated (handled by repository).
final class FollowOperationsProvider
    extends $NotifierProvider<FollowOperations, Set<String>> {
  /// Notifier for managing follow state and operations
  /// - Checks if current user is following a pubkey
  /// - Tracks which pubkeys have active follow/unfollow operations
  /// - Provides follow/unfollow/toggle actions
  ///
  /// Operations become no-ops when not authenticated (handled by repository).
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

String _$followOperationsHash() => r'2bdbf530f4a22cad01b320f2a0bb04bad476d554';

/// Notifier for managing follow state and operations
/// - Checks if current user is following a pubkey
/// - Tracks which pubkeys have active follow/unfollow operations
/// - Provides follow/unfollow/toggle actions
///
/// Operations become no-ops when not authenticated (handled by repository).

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
