// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_relationship_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Populates the current user's follower cache once per session.
///
/// [FollowRepository.relationshipTo] reads that cache but never fills it, and
/// a user row must not trigger its own fetch — one shared warm-up keeps the
/// cost at one request per session instead of one per visible row.
///
/// Completes with no value on failure: an unreachable relay degrades the
/// relationship to "unknown", which [FollowRelationship] already models, and
/// is not worth surfacing on a secondary identifier line.

@ProviderFor(myFollowersWarmup)
final myFollowersWarmupProvider = MyFollowersWarmupProvider._();

/// Populates the current user's follower cache once per session.
///
/// [FollowRepository.relationshipTo] reads that cache but never fills it, and
/// a user row must not trigger its own fetch — one shared warm-up keeps the
/// cost at one request per session instead of one per visible row.
///
/// Completes with no value on failure: an unreachable relay degrades the
/// relationship to "unknown", which [FollowRelationship] already models, and
/// is not worth surfacing on a secondary identifier line.

final class MyFollowersWarmupProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Populates the current user's follower cache once per session.
  ///
  /// [FollowRepository.relationshipTo] reads that cache but never fills it, and
  /// a user row must not trigger its own fetch — one shared warm-up keeps the
  /// cost at one request per session instead of one per visible row.
  ///
  /// Completes with no value on failure: an unreachable relay degrades the
  /// relationship to "unknown", which [FollowRelationship] already models, and
  /// is not worth surfacing on a secondary identifier line.
  MyFollowersWarmupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myFollowersWarmupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myFollowersWarmupHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return myFollowersWarmup(ref);
  }
}

String _$myFollowersWarmupHash() => r'544631a238ec616cf74ef8ff475a97020eed7686';

/// The current user's follow relationship with [pubkey], kept live.
///
/// Re-emits when the current user's following list changes and again when the
/// follower warm-up lands, so a row that first renders as
/// [FollowRelationship.youFollow] upgrades to [FollowRelationship.mutual]
/// without a rebuild of the surrounding list.

@ProviderFor(followRelationship)
final followRelationshipProvider = FollowRelationshipFamily._();

/// The current user's follow relationship with [pubkey], kept live.
///
/// Re-emits when the current user's following list changes and again when the
/// follower warm-up lands, so a row that first renders as
/// [FollowRelationship.youFollow] upgrades to [FollowRelationship.mutual]
/// without a rebuild of the surrounding list.

final class FollowRelationshipProvider
    extends
        $FunctionalProvider<
          AsyncValue<FollowRelationship>,
          FollowRelationship,
          Stream<FollowRelationship>
        >
    with
        $FutureModifier<FollowRelationship>,
        $StreamProvider<FollowRelationship> {
  /// The current user's follow relationship with [pubkey], kept live.
  ///
  /// Re-emits when the current user's following list changes and again when the
  /// follower warm-up lands, so a row that first renders as
  /// [FollowRelationship.youFollow] upgrades to [FollowRelationship.mutual]
  /// without a rebuild of the surrounding list.
  FollowRelationshipProvider._({
    required FollowRelationshipFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'followRelationshipProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$followRelationshipHash();

  @override
  String toString() {
    return r'followRelationshipProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<FollowRelationship> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<FollowRelationship> create(Ref ref) {
    final argument = this.argument as String;
    return followRelationship(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FollowRelationshipProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$followRelationshipHash() =>
    r'702f16242ad7aa7ef1bfc36c1128a2b6199efad9';

/// The current user's follow relationship with [pubkey], kept live.
///
/// Re-emits when the current user's following list changes and again when the
/// follower warm-up lands, so a row that first renders as
/// [FollowRelationship.youFollow] upgrades to [FollowRelationship.mutual]
/// without a rebuild of the surrounding list.

final class FollowRelationshipFamily extends $Family
    with $FunctionalFamilyOverride<Stream<FollowRelationship>, String> {
  FollowRelationshipFamily._()
    : super(
        retry: null,
        name: r'followRelationshipProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The current user's follow relationship with [pubkey], kept live.
  ///
  /// Re-emits when the current user's following list changes and again when the
  /// follower warm-up lands, so a row that first renders as
  /// [FollowRelationship.youFollow] upgrades to [FollowRelationship.mutual]
  /// without a rebuild of the surrounding list.

  FollowRelationshipProvider call(String pubkey) =>
      FollowRelationshipProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'followRelationshipProvider';
}
