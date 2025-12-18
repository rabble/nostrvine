// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'following_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for fetching and managing a user's following list
/// - For current user: uses FollowRepository (reactive updates)
/// - For other users: fetches from Nostr relays

@ProviderFor(FollowingListNotifier)
const followingListProvider = FollowingListNotifierFamily._();

/// Provider for fetching and managing a user's following list
/// - For current user: uses FollowRepository (reactive updates)
/// - For other users: fetches from Nostr relays
final class FollowingListNotifierProvider
    extends $AsyncNotifierProvider<FollowingListNotifier, List<String>> {
  /// Provider for fetching and managing a user's following list
  /// - For current user: uses FollowRepository (reactive updates)
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
    r'bda795bfbf26d7db46bc757154c40b78a1388a67';

/// Provider for fetching and managing a user's following list
/// - For current user: uses FollowRepository (reactive updates)
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
  /// - For current user: uses FollowRepository (reactive updates)
  /// - For other users: fetches from Nostr relays

  FollowingListNotifierProvider call(String pubkey) =>
      FollowingListNotifierProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'followingListProvider';
}

/// Provider for fetching and managing a user's following list
/// - For current user: uses FollowRepository (reactive updates)
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
    r'cc09dddd80210557abf75e01bf4192314b06629e';
