// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for all user lists (kind 30000 - people lists)

@ProviderFor(userLists)
const userListsProvider = UserListsProvider._();

/// Provider for all user lists (kind 30000 - people lists)

final class UserListsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<UserList>>,
          List<UserList>,
          FutureOr<List<UserList>>
        >
    with $FutureModifier<List<UserList>>, $FutureProvider<List<UserList>> {
  /// Provider for all user lists (kind 30000 - people lists)
  const UserListsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userListsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userListsHash();

  @$internal
  @override
  $FutureProviderElement<List<UserList>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<UserList>> create(Ref ref) {
    return userLists(ref);
  }
}

String _$userListsHash() => r'dc1bef2ba8574f8c26a348c27b5cdb0d7aff077f';

/// Provider for all curated video lists (kind 30005)

@ProviderFor(curatedLists)
const curatedListsProvider = CuratedListsProvider._();

/// Provider for all curated video lists (kind 30005)

final class CuratedListsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CuratedList>>,
          List<CuratedList>,
          FutureOr<List<CuratedList>>
        >
    with
        $FutureModifier<List<CuratedList>>,
        $FutureProvider<List<CuratedList>> {
  /// Provider for all curated video lists (kind 30005)
  const CuratedListsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curatedListsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curatedListsHash();

  @$internal
  @override
  $FutureProviderElement<List<CuratedList>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CuratedList>> create(Ref ref) {
    return curatedLists(ref);
  }
}

String _$curatedListsHash() => r'74de3f9b86d5444e78e7f2c797370ca75f29f9f5';

/// Combined provider for both types of lists

@ProviderFor(allLists)
const allListsProvider = AllListsProvider._();

/// Combined provider for both types of lists

final class AllListsProvider
    extends
        $FunctionalProvider<
          AsyncValue<
            ({List<CuratedList> curatedLists, List<UserList> userLists})
          >,
          ({List<CuratedList> curatedLists, List<UserList> userLists}),
          FutureOr<({List<CuratedList> curatedLists, List<UserList> userLists})>
        >
    with
        $FutureModifier<
          ({List<CuratedList> curatedLists, List<UserList> userLists})
        >,
        $FutureProvider<
          ({List<CuratedList> curatedLists, List<UserList> userLists})
        > {
  /// Combined provider for both types of lists
  const AllListsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allListsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allListsHash();

  @$internal
  @override
  $FutureProviderElement<
    ({List<CuratedList> curatedLists, List<UserList> userLists})
  >
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({List<CuratedList> curatedLists, List<UserList> userLists})> create(
    Ref ref,
  ) {
    return allLists(ref);
  }
}

String _$allListsHash() => r'8d7c4fb84d445151d5bb84764da34cedf4e7e8a6';

/// Provider that caches discovered public lists across navigation
/// This persists the lists so they're not lost when leaving/returning to screen

@ProviderFor(DiscoveredLists)
const discoveredListsProvider = DiscoveredListsProvider._();

/// Provider that caches discovered public lists across navigation
/// This persists the lists so they're not lost when leaving/returning to screen
final class DiscoveredListsProvider
    extends $NotifierProvider<DiscoveredLists, DiscoveredListsState> {
  /// Provider that caches discovered public lists across navigation
  /// This persists the lists so they're not lost when leaving/returning to screen
  const DiscoveredListsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveredListsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveredListsHash();

  @$internal
  @override
  DiscoveredLists create() => DiscoveredLists();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiscoveredListsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiscoveredListsState>(value),
    );
  }
}

String _$discoveredListsHash() => r'9e2be25f90d5cab30d9183aba33e474201db0938';

/// Provider that caches discovered public lists across navigation
/// This persists the lists so they're not lost when leaving/returning to screen

abstract class _$DiscoveredLists extends $Notifier<DiscoveredListsState> {
  DiscoveredListsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<DiscoveredListsState, DiscoveredListsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DiscoveredListsState, DiscoveredListsState>,
              DiscoveredListsState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for videos in a specific curated list

@ProviderFor(curatedListVideos)
const curatedListVideosProvider = CuratedListVideosFamily._();

/// Provider for videos in a specific curated list

final class CuratedListVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Provider for videos in a specific curated list
  const CuratedListVideosProvider._({
    required CuratedListVideosFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'curatedListVideosProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$curatedListVideosHash();

  @override
  String toString() {
    return r'curatedListVideosProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    final argument = this.argument as String;
    return curatedListVideos(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CuratedListVideosProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$curatedListVideosHash() => r'80f09cbd14d104bfb09922ffb3e3ba3cd0d9c6fe';

/// Provider for videos in a specific curated list

final class CuratedListVideosFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, String> {
  const CuratedListVideosFamily._()
    : super(
        retry: null,
        name: r'curatedListVideosProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for videos in a specific curated list

  CuratedListVideosProvider call(String listId) =>
      CuratedListVideosProvider._(argument: listId, from: this);

  @override
  String toString() => r'curatedListVideosProvider';
}

/// Provider for videos from all members of a user list

@ProviderFor(userListMemberVideos)
const userListMemberVideosProvider = UserListMemberVideosFamily._();

/// Provider for videos from all members of a user list

final class UserListMemberVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          Stream<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $StreamProvider<List<VideoEvent>> {
  /// Provider for videos from all members of a user list
  const UserListMemberVideosProvider._({
    required UserListMemberVideosFamily super.from,
    required List<String> super.argument,
  }) : super(
         retry: null,
         name: r'userListMemberVideosProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userListMemberVideosHash();

  @override
  String toString() {
    return r'userListMemberVideosProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<VideoEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<VideoEvent>> create(Ref ref) {
    final argument = this.argument as List<String>;
    return userListMemberVideos(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserListMemberVideosProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userListMemberVideosHash() =>
    r'005a02b0974013a6cc82aec093a1e17cf5cc4020';

/// Provider for videos from all members of a user list

final class UserListMemberVideosFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<VideoEvent>>, List<String>> {
  const UserListMemberVideosFamily._()
    : super(
        retry: null,
        name: r'userListMemberVideosProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for videos from all members of a user list

  UserListMemberVideosProvider call(List<String> pubkeys) =>
      UserListMemberVideosProvider._(argument: pubkeys, from: this);

  @override
  String toString() => r'userListMemberVideosProvider';
}

/// Provider that streams public lists containing a specific video
/// Accumulates results as they arrive from Nostr relays, yielding updated list
/// on each new result. This enables progressive UI updates via Riverpod.

@ProviderFor(publicListsContainingVideo)
const publicListsContainingVideoProvider = PublicListsContainingVideoFamily._();

/// Provider that streams public lists containing a specific video
/// Accumulates results as they arrive from Nostr relays, yielding updated list
/// on each new result. This enables progressive UI updates via Riverpod.

final class PublicListsContainingVideoProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CuratedList>>,
          List<CuratedList>,
          Stream<List<CuratedList>>
        >
    with
        $FutureModifier<List<CuratedList>>,
        $StreamProvider<List<CuratedList>> {
  /// Provider that streams public lists containing a specific video
  /// Accumulates results as they arrive from Nostr relays, yielding updated list
  /// on each new result. This enables progressive UI updates via Riverpod.
  const PublicListsContainingVideoProvider._({
    required PublicListsContainingVideoFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'publicListsContainingVideoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$publicListsContainingVideoHash();

  @override
  String toString() {
    return r'publicListsContainingVideoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<CuratedList>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CuratedList>> create(Ref ref) {
    final argument = this.argument as String;
    return publicListsContainingVideo(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PublicListsContainingVideoProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$publicListsContainingVideoHash() =>
    r'643ef43d10db7ac5b9d96981f551c2cdc92081ac';

/// Provider that streams public lists containing a specific video
/// Accumulates results as they arrive from Nostr relays, yielding updated list
/// on each new result. This enables progressive UI updates via Riverpod.

final class PublicListsContainingVideoFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<CuratedList>>, String> {
  const PublicListsContainingVideoFamily._()
    : super(
        retry: null,
        name: r'publicListsContainingVideoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that streams public lists containing a specific video
  /// Accumulates results as they arrive from Nostr relays, yielding updated list
  /// on each new result. This enables progressive UI updates via Riverpod.

  PublicListsContainingVideoProvider call(String videoId) =>
      PublicListsContainingVideoProvider._(argument: videoId, from: this);

  @override
  String toString() => r'publicListsContainingVideoProvider';
}

/// Provider that fetches actual VideoEvent objects for a curated list
/// Streams videos as they are fetched from cache or relays

@ProviderFor(curatedListVideoEvents)
const curatedListVideoEventsProvider = CuratedListVideoEventsFamily._();

/// Provider that fetches actual VideoEvent objects for a curated list
/// Streams videos as they are fetched from cache or relays

final class CuratedListVideoEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          Stream<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $StreamProvider<List<VideoEvent>> {
  /// Provider that fetches actual VideoEvent objects for a curated list
  /// Streams videos as they are fetched from cache or relays
  const CuratedListVideoEventsProvider._({
    required CuratedListVideoEventsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'curatedListVideoEventsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$curatedListVideoEventsHash();

  @override
  String toString() {
    return r'curatedListVideoEventsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<VideoEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<VideoEvent>> create(Ref ref) {
    final argument = this.argument as String;
    return curatedListVideoEvents(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CuratedListVideoEventsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$curatedListVideoEventsHash() =>
    r'ad1646f4833e31b7c0be36da69a8d583b117449a';

/// Provider that fetches actual VideoEvent objects for a curated list
/// Streams videos as they are fetched from cache or relays

final class CuratedListVideoEventsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<VideoEvent>>, String> {
  const CuratedListVideoEventsFamily._()
    : super(
        retry: null,
        name: r'curatedListVideoEventsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that fetches actual VideoEvent objects for a curated list
  /// Streams videos as they are fetched from cache or relays

  CuratedListVideoEventsProvider call(String listId) =>
      CuratedListVideoEventsProvider._(argument: listId, from: this);

  @override
  String toString() => r'curatedListVideoEventsProvider';
}

/// Provider that fetches VideoEvent objects directly from a list of video IDs
/// Use this for discovered lists that aren't in local storage

@ProviderFor(videoEventsByIds)
const videoEventsByIdsProvider = VideoEventsByIdsFamily._();

/// Provider that fetches VideoEvent objects directly from a list of video IDs
/// Use this for discovered lists that aren't in local storage

final class VideoEventsByIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          Stream<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $StreamProvider<List<VideoEvent>> {
  /// Provider that fetches VideoEvent objects directly from a list of video IDs
  /// Use this for discovered lists that aren't in local storage
  const VideoEventsByIdsProvider._({
    required VideoEventsByIdsFamily super.from,
    required List<String> super.argument,
  }) : super(
         retry: null,
         name: r'videoEventsByIdsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$videoEventsByIdsHash();

  @override
  String toString() {
    return r'videoEventsByIdsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<VideoEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<VideoEvent>> create(Ref ref) {
    final argument = this.argument as List<String>;
    return videoEventsByIds(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VideoEventsByIdsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$videoEventsByIdsHash() => r'149abcf76b2ae57e82cdb4fd3b440c5866cb582a';

/// Provider that fetches VideoEvent objects directly from a list of video IDs
/// Use this for discovered lists that aren't in local storage

final class VideoEventsByIdsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<VideoEvent>>, List<String>> {
  const VideoEventsByIdsFamily._()
    : super(
        retry: null,
        name: r'videoEventsByIdsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that fetches VideoEvent objects directly from a list of video IDs
  /// Use this for discovered lists that aren't in local storage

  VideoEventsByIdsProvider call(List<String> videoIds) =>
      VideoEventsByIdsProvider._(argument: videoIds, from: this);

  @override
  String toString() => r'videoEventsByIdsProvider';
}
