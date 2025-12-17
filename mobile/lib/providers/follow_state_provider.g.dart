// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing follow state and operations
/// - Checks if current user is following a pubkey
/// - Tracks which pubkeys have active follow/unfollow operations
/// - Provides follow/unfollow/toggle actions

@ProviderFor(FollowOperations)
const followOperationsProvider = FollowOperationsProvider._();

/// Notifier for managing follow state and operations
/// - Checks if current user is following a pubkey
/// - Tracks which pubkeys have active follow/unfollow operations
/// - Provides follow/unfollow/toggle actions
final class FollowOperationsProvider
    extends $NotifierProvider<FollowOperations, Set<String>> {
  /// Notifier for managing follow state and operations
  /// - Checks if current user is following a pubkey
  /// - Tracks which pubkeys have active follow/unfollow operations
  /// - Provides follow/unfollow/toggle actions
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

String _$followOperationsHash() => r'ed139061c0195ac40c6817f1bd3dc69c22fc227f';

/// Notifier for managing follow state and operations
/// - Checks if current user is following a pubkey
/// - Tracks which pubkeys have active follow/unfollow operations
/// - Provides follow/unfollow/toggle actions

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
