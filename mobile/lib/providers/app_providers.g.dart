// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pending action service for offline sync of social actions
/// Returns null when not authenticated (no userPubkey available)

@ProviderFor(pendingActionService)
const pendingActionServiceProvider = PendingActionServiceProvider._();

/// Pending action service for offline sync of social actions
/// Returns null when not authenticated (no userPubkey available)

final class PendingActionServiceProvider
    extends
        $FunctionalProvider<
          PendingActionService?,
          PendingActionService?,
          PendingActionService?
        >
    with $Provider<PendingActionService?> {
  /// Pending action service for offline sync of social actions
  /// Returns null when not authenticated (no userPubkey available)
  const PendingActionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingActionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingActionServiceHash();

  @$internal
  @override
  $ProviderElement<PendingActionService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PendingActionService? create(Ref ref) {
    return pendingActionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingActionService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingActionService?>(value),
    );
  }
}

String _$pendingActionServiceHash() =>
    r'67a3a30b8cc1072263ce47f4e2bb3c34fa876fa1';

/// Auto-sweep service for the durable `outgoing_dms` queue.
///
/// Listens to app-foreground transitions and re-publishes the missing
/// self-wrap for any row in `recipient: sent / self: failed` state via
/// [DmRepository.recoverSelfWrap]. Closes the gap left by the
/// SnackBar-only manual retry from PR #4106 — see issue #4124.
///
/// The service is keepAlive but has no UI consumer, so it is read
/// eagerly at app shell startup (`main.dart`) so the foreground
/// subscription is wired up.
///
/// Returns null when the user is not authenticated or when the current Nostr
/// session is not ready — the underlying [DmRepository.recoverSelfWrap]
/// requires `setCredentials` to have run, and gating here is cleaner than
/// catching `StateError` in every sweep pass.

@ProviderFor(outgoingDmRetryService)
const outgoingDmRetryServiceProvider = OutgoingDmRetryServiceProvider._();

/// Auto-sweep service for the durable `outgoing_dms` queue.
///
/// Listens to app-foreground transitions and re-publishes the missing
/// self-wrap for any row in `recipient: sent / self: failed` state via
/// [DmRepository.recoverSelfWrap]. Closes the gap left by the
/// SnackBar-only manual retry from PR #4106 — see issue #4124.
///
/// The service is keepAlive but has no UI consumer, so it is read
/// eagerly at app shell startup (`main.dart`) so the foreground
/// subscription is wired up.
///
/// Returns null when the user is not authenticated or when the current Nostr
/// session is not ready — the underlying [DmRepository.recoverSelfWrap]
/// requires `setCredentials` to have run, and gating here is cleaner than
/// catching `StateError` in every sweep pass.

final class OutgoingDmRetryServiceProvider
    extends
        $FunctionalProvider<
          OutgoingDmRetryService?,
          OutgoingDmRetryService?,
          OutgoingDmRetryService?
        >
    with $Provider<OutgoingDmRetryService?> {
  /// Auto-sweep service for the durable `outgoing_dms` queue.
  ///
  /// Listens to app-foreground transitions and re-publishes the missing
  /// self-wrap for any row in `recipient: sent / self: failed` state via
  /// [DmRepository.recoverSelfWrap]. Closes the gap left by the
  /// SnackBar-only manual retry from PR #4106 — see issue #4124.
  ///
  /// The service is keepAlive but has no UI consumer, so it is read
  /// eagerly at app shell startup (`main.dart`) so the foreground
  /// subscription is wired up.
  ///
  /// Returns null when the user is not authenticated or when the current Nostr
  /// session is not ready — the underlying [DmRepository.recoverSelfWrap]
  /// requires `setCredentials` to have run, and gating here is cleaner than
  /// catching `StateError` in every sweep pass.
  const OutgoingDmRetryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outgoingDmRetryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outgoingDmRetryServiceHash();

  @$internal
  @override
  $ProviderElement<OutgoingDmRetryService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OutgoingDmRetryService? create(Ref ref) {
    return outgoingDmRetryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OutgoingDmRetryService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OutgoingDmRetryService?>(value),
    );
  }
}

String _$outgoingDmRetryServiceHash() =>
    r'ccbee39cf920a0847be410ca804e048200962d38';

/// Analytics service with opt-out support.
///
/// Publishes Kind 22236 ephemeral Nostr view events via [ViewEventPublisher].

@ProviderFor(analyticsService)
const analyticsServiceProvider = AnalyticsServiceProvider._();

/// Analytics service with opt-out support.
///
/// Publishes Kind 22236 ephemeral Nostr view events via [ViewEventPublisher].

final class AnalyticsServiceProvider
    extends
        $FunctionalProvider<
          AnalyticsService,
          AnalyticsService,
          AnalyticsService
        >
    with $Provider<AnalyticsService> {
  /// Analytics service with opt-out support.
  ///
  /// Publishes Kind 22236 ephemeral Nostr view events via [ViewEventPublisher].
  const AnalyticsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsServiceHash();

  @$internal
  @override
  $ProviderElement<AnalyticsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AnalyticsService create(Ref ref) {
    return analyticsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyticsService>(value),
    );
  }
}

String _$analyticsServiceHash() => r'e6375a363ad078b11017d729f4a53e062b855f4e';

/// Hashtag cache service for persistent hashtag storage

@ProviderFor(hashtagCacheService)
const hashtagCacheServiceProvider = HashtagCacheServiceProvider._();

/// Hashtag cache service for persistent hashtag storage

final class HashtagCacheServiceProvider
    extends
        $FunctionalProvider<
          HashtagCacheService,
          HashtagCacheService,
          HashtagCacheService
        >
    with $Provider<HashtagCacheService> {
  /// Hashtag cache service for persistent hashtag storage
  const HashtagCacheServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hashtagCacheServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hashtagCacheServiceHash();

  @$internal
  @override
  $ProviderElement<HashtagCacheService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HashtagCacheService create(Ref ref) {
    return hashtagCacheService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HashtagCacheService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HashtagCacheService>(value),
    );
  }
}

String _$hashtagCacheServiceHash() =>
    r'9cc0bce9cded786f95dc83e7bf6dbcbc2602e907';

/// Draft storage service for persisting vine drafts

@ProviderFor(draftStorageService)
const draftStorageServiceProvider = DraftStorageServiceProvider._();

/// Draft storage service for persisting vine drafts

final class DraftStorageServiceProvider
    extends
        $FunctionalProvider<
          DraftStorageService,
          DraftStorageService,
          DraftStorageService
        >
    with $Provider<DraftStorageService> {
  /// Draft storage service for persisting vine drafts
  const DraftStorageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'draftStorageServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$draftStorageServiceHash();

  @$internal
  @override
  $ProviderElement<DraftStorageService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DraftStorageService create(Ref ref) {
    return draftStorageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DraftStorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DraftStorageService>(value),
    );
  }
}

String _$draftStorageServiceHash() =>
    r'1ef3ccee1fdbb86f842c2bdf448b7f72d4e8f629';

/// Clip library service for persisting individual video clips

@ProviderFor(clipLibraryService)
const clipLibraryServiceProvider = ClipLibraryServiceProvider._();

/// Clip library service for persisting individual video clips

final class ClipLibraryServiceProvider
    extends
        $FunctionalProvider<
          ClipLibraryService,
          ClipLibraryService,
          ClipLibraryService
        >
    with $Provider<ClipLibraryService> {
  /// Clip library service for persisting individual video clips
  const ClipLibraryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipLibraryServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipLibraryServiceHash();

  @$internal
  @override
  $ProviderElement<ClipLibraryService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ClipLibraryService create(Ref ref) {
    return clipLibraryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipLibraryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipLibraryService>(value),
    );
  }
}

String _$clipLibraryServiceHash() =>
    r'f36b3e22012c58da8f70d620378448bbe500f0cc';

/// User data cleanup service for handling identity changes
/// Prevents data leakage between different Nostr accounts

@ProviderFor(userDataCleanupService)
const userDataCleanupServiceProvider = UserDataCleanupServiceProvider._();

/// User data cleanup service for handling identity changes
/// Prevents data leakage between different Nostr accounts

final class UserDataCleanupServiceProvider
    extends
        $FunctionalProvider<
          UserDataCleanupService,
          UserDataCleanupService,
          UserDataCleanupService
        >
    with $Provider<UserDataCleanupService> {
  /// User data cleanup service for handling identity changes
  /// Prevents data leakage between different Nostr accounts
  const UserDataCleanupServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userDataCleanupServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userDataCleanupServiceHash();

  @$internal
  @override
  $ProviderElement<UserDataCleanupService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UserDataCleanupService create(Ref ref) {
    return userDataCleanupService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserDataCleanupService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserDataCleanupService>(value),
    );
  }
}

String _$userDataCleanupServiceHash() =>
    r'6a327dc21d05b9ec426424250176bfe8c1e42a41';

/// Hashtag service depends on Video event service and cache service

@ProviderFor(hashtagService)
const hashtagServiceProvider = HashtagServiceProvider._();

/// Hashtag service depends on Video event service and cache service

final class HashtagServiceProvider
    extends $FunctionalProvider<HashtagService, HashtagService, HashtagService>
    with $Provider<HashtagService> {
  /// Hashtag service depends on Video event service and cache service
  const HashtagServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hashtagServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hashtagServiceHash();

  @$internal
  @override
  $ProviderElement<HashtagService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HashtagService create(Ref ref) {
    return hashtagService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HashtagService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HashtagService>(value),
    );
  }
}

String _$hashtagServiceHash() => r'5cd38d3c2e8d78a6f7b74a72b650d79e28938fe4';

/// Social service for follow sets (NIP-51 Kind 30000).
///
/// Follower count stats have moved to [FollowRepository].

@ProviderFor(socialService)
const socialServiceProvider = SocialServiceProvider._();

/// Social service for follow sets (NIP-51 Kind 30000).
///
/// Follower count stats have moved to [FollowRepository].

final class SocialServiceProvider
    extends $FunctionalProvider<SocialService, SocialService, SocialService>
    with $Provider<SocialService> {
  /// Social service for follow sets (NIP-51 Kind 30000).
  ///
  /// Follower count stats have moved to [FollowRepository].
  const SocialServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'socialServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$socialServiceHash();

  @$internal
  @override
  $ProviderElement<SocialService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SocialService create(Ref ref) {
    return socialService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SocialService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SocialService>(value),
    );
  }
}

String _$socialServiceHash() => r'025a0d7f80743f11d040e4867c012397282404b3';

/// Cached following list loaded directly from SharedPreferences.
///
/// Available immediately after authentication (no NostrClient needed).
/// This provides the follow list from the previous session for instant
/// feed display. The full FollowRepository will update this when ready.

@ProviderFor(cachedFollowingList)
const cachedFollowingListProvider = CachedFollowingListProvider._();

/// Cached following list loaded directly from SharedPreferences.
///
/// Available immediately after authentication (no NostrClient needed).
/// This provides the follow list from the previous session for instant
/// feed display. The full FollowRepository will update this when ready.

final class CachedFollowingListProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  /// Cached following list loaded directly from SharedPreferences.
  ///
  /// Available immediately after authentication (no NostrClient needed).
  /// This provides the follow list from the previous session for instant
  /// feed display. The full FollowRepository will update this when ready.
  const CachedFollowingListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cachedFollowingListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cachedFollowingListHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return cachedFollowingList(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$cachedFollowingListHash() =>
    r'9aae18333a2883db193f61b69a4d12a5e58899ac';

/// Provider for FollowRepository instance
///
/// Creates a FollowRepository for managing follow relationships.
/// Non-nullable: the repository works without keys at construction time.
/// Read operations return cached/empty data; write operations check keys.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalEventCacheService (for caching contact list events)

@ProviderFor(followRepository)
const followRepositoryProvider = FollowRepositoryProvider._();

/// Provider for FollowRepository instance
///
/// Creates a FollowRepository for managing follow relationships.
/// Non-nullable: the repository works without keys at construction time.
/// Read operations return cached/empty data; write operations check keys.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalEventCacheService (for caching contact list events)

final class FollowRepositoryProvider
    extends
        $FunctionalProvider<
          FollowRepository,
          FollowRepository,
          FollowRepository
        >
    with $Provider<FollowRepository> {
  /// Provider for FollowRepository instance
  ///
  /// Creates a FollowRepository for managing follow relationships.
  /// Non-nullable: the repository works without keys at construction time.
  /// Read operations return cached/empty data; write operations check keys.
  ///
  /// Uses:
  /// - NostrClient from nostrServiceProvider (for relay communication)
  /// - PersonalEventCacheService (for caching contact list events)
  const FollowRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'followRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$followRepositoryHash();

  @$internal
  @override
  $ProviderElement<FollowRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FollowRepository create(Ref ref) {
    return followRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FollowRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FollowRepository>(value),
    );
  }
}

String _$followRepositoryHash() => r'fb0dd5265e3906366876638e6a2026d1b672e8c9';

/// Provider for [CuratedListRepository] instance.
///
/// Creates a repository that exposes subscribed curated lists via a
/// [BehaviorSubject] stream for reactive BLoC subscription. Data is
/// bridged from the legacy [CuratedListService] via [setSubscribedLists]
/// until the repository owns its own persistence (Phase 1b).

@ProviderFor(curatedListRepository)
const curatedListRepositoryProvider = CuratedListRepositoryProvider._();

/// Provider for [CuratedListRepository] instance.
///
/// Creates a repository that exposes subscribed curated lists via a
/// [BehaviorSubject] stream for reactive BLoC subscription. Data is
/// bridged from the legacy [CuratedListService] via [setSubscribedLists]
/// until the repository owns its own persistence (Phase 1b).

final class CuratedListRepositoryProvider
    extends
        $FunctionalProvider<
          CuratedListRepository,
          CuratedListRepository,
          CuratedListRepository
        >
    with $Provider<CuratedListRepository> {
  /// Provider for [CuratedListRepository] instance.
  ///
  /// Creates a repository that exposes subscribed curated lists via a
  /// [BehaviorSubject] stream for reactive BLoC subscription. Data is
  /// bridged from the legacy [CuratedListService] via [setSubscribedLists]
  /// until the repository owns its own persistence (Phase 1b).
  const CuratedListRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curatedListRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curatedListRepositoryHash();

  @$internal
  @override
  $ProviderElement<CuratedListRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CuratedListRepository create(Ref ref) {
    return curatedListRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CuratedListRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CuratedListRepository>(value),
    );
  }
}

String _$curatedListRepositoryHash() =>
    r'83597beceb9432e6c558312d4ada0d40bc6ebeb8';

/// Provider for HashtagRepository instance.
///
/// Creates a HashtagRepository for searching hashtags via the Funnelcake API.

@ProviderFor(hashtagRepository)
const hashtagRepositoryProvider = HashtagRepositoryProvider._();

/// Provider for HashtagRepository instance.
///
/// Creates a HashtagRepository for searching hashtags via the Funnelcake API.

final class HashtagRepositoryProvider
    extends
        $FunctionalProvider<
          HashtagRepository,
          HashtagRepository,
          HashtagRepository
        >
    with $Provider<HashtagRepository> {
  /// Provider for HashtagRepository instance.
  ///
  /// Creates a HashtagRepository for searching hashtags via the Funnelcake API.
  const HashtagRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hashtagRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hashtagRepositoryHash();

  @$internal
  @override
  $ProviderElement<HashtagRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HashtagRepository create(Ref ref) {
    return hashtagRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HashtagRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HashtagRepository>(value),
    );
  }
}

String _$hashtagRepositoryHash() => r'fe5341fcbbd62c6418fd00154f9ea24112476251';

/// Provider for CategoriesRepository instance.
///
/// Keep-alive so the categories cache survives tab and screen transitions.

@ProviderFor(categoriesRepository)
const categoriesRepositoryProvider = CategoriesRepositoryProvider._();

/// Provider for CategoriesRepository instance.
///
/// Keep-alive so the categories cache survives tab and screen transitions.

final class CategoriesRepositoryProvider
    extends
        $FunctionalProvider<
          CategoriesRepository,
          CategoriesRepository,
          CategoriesRepository
        >
    with $Provider<CategoriesRepository> {
  /// Provider for CategoriesRepository instance.
  ///
  /// Keep-alive so the categories cache survives tab and screen transitions.
  const CategoriesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoriesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoriesRepositoryHash();

  @$internal
  @override
  $ProviderElement<CategoriesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CategoriesRepository create(Ref ref) {
    return categoriesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoriesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoriesRepository>(value),
    );
  }
}

String _$categoriesRepositoryHash() =>
    r'6a3a483ae2565033933e9891b1742571c6e15fa8';

/// Provider for ProfileRepository instance
///
/// Creates a ProfileRepository for managing user profiles (Kind 0 metadata).
/// Requires authentication.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - FunnelcakeApiClient for fast REST-based profile search

@ProviderFor(profileRepository)
const profileRepositoryProvider = ProfileRepositoryProvider._();

/// Provider for ProfileRepository instance
///
/// Creates a ProfileRepository for managing user profiles (Kind 0 metadata).
/// Requires authentication.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - FunnelcakeApiClient for fast REST-based profile search

final class ProfileRepositoryProvider
    extends
        $FunctionalProvider<
          ProfileRepository?,
          ProfileRepository?,
          ProfileRepository?
        >
    with $Provider<ProfileRepository?> {
  /// Provider for ProfileRepository instance
  ///
  /// Creates a ProfileRepository for managing user profiles (Kind 0 metadata).
  /// Requires authentication.
  ///
  /// Uses:
  /// - NostrClient from nostrServiceProvider (for relay communication)
  /// - FunnelcakeApiClient for fast REST-based profile search
  const ProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileRepository? create(Ref ref) {
    return profileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileRepository?>(value),
    );
  }
}

String _$profileRepositoryHash() => r'323c17d6613c13649f8738e6d418a0318294b265';

/// Curation Service - manages NIP-51 video curation sets

@ProviderFor(curationRepository)
const curationRepositoryProvider = CurationRepositoryProvider._();

/// Curation Service - manages NIP-51 video curation sets

final class CurationRepositoryProvider
    extends
        $FunctionalProvider<
          CurationRepository,
          CurationRepository,
          CurationRepository
        >
    with $Provider<CurationRepository> {
  /// Curation Service - manages NIP-51 video curation sets
  const CurationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curationRepositoryHash();

  @$internal
  @override
  $ProviderElement<CurationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CurationRepository create(Ref ref) {
    return curationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurationRepository>(value),
    );
  }
}

String _$curationRepositoryHash() =>
    r'a1a9ce03d658dd1bf9c924270bd9dacd0d070a56';

/// Content reporting service for NIP-56 compliance

@ProviderFor(contentReportingService)
const contentReportingServiceProvider = ContentReportingServiceProvider._();

/// Content reporting service for NIP-56 compliance

final class ContentReportingServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentReportingService>,
          ContentReportingService,
          FutureOr<ContentReportingService>
        >
    with
        $FutureModifier<ContentReportingService>,
        $FutureProvider<ContentReportingService> {
  /// Content reporting service for NIP-56 compliance
  const ContentReportingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentReportingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentReportingServiceHash();

  @$internal
  @override
  $FutureProviderElement<ContentReportingService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContentReportingService> create(Ref ref) {
    return contentReportingService(ref);
  }
}

String _$contentReportingServiceHash() =>
    r'5f32ae82aae7471e3e3dd008a011607def6bc149';

/// Lists state notifier - manages curated lists state

@ProviderFor(CuratedListsState)
const curatedListsStateProvider = CuratedListsStateProvider._();

/// Lists state notifier - manages curated lists state
final class CuratedListsStateProvider
    extends $AsyncNotifierProvider<CuratedListsState, List<CuratedList>> {
  /// Lists state notifier - manages curated lists state
  const CuratedListsStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curatedListsStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curatedListsStateHash();

  @$internal
  @override
  CuratedListsState create() => CuratedListsState();
}

String _$curatedListsStateHash() => r'c6255dcf311db8ce01adb1aa64f5b40e38bd9729';

/// Lists state notifier - manages curated lists state

abstract class _$CuratedListsState extends $AsyncNotifier<List<CuratedList>> {
  FutureOr<List<CuratedList>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<CuratedList>>, List<CuratedList>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<CuratedList>>, List<CuratedList>>,
              AsyncValue<List<CuratedList>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Repository for NIP-51 kind 30000 people lists.
///
/// Wires the shared [NostrClient] (via [nostrServiceProvider]) into a
/// [PeopleListsRepositoryImpl] backed by a [LocalPeopleListsCache] that opens
/// a lazily-created `hive_ce` box named [_peopleListsBoxName]. The repository
/// itself has no Flutter dependencies; this provider owns all UI glue.

@ProviderFor(peopleListsRepository)
const peopleListsRepositoryProvider = PeopleListsRepositoryProvider._();

/// Repository for NIP-51 kind 30000 people lists.
///
/// Wires the shared [NostrClient] (via [nostrServiceProvider]) into a
/// [PeopleListsRepositoryImpl] backed by a [LocalPeopleListsCache] that opens
/// a lazily-created `hive_ce` box named [_peopleListsBoxName]. The repository
/// itself has no Flutter dependencies; this provider owns all UI glue.

final class PeopleListsRepositoryProvider
    extends
        $FunctionalProvider<
          PeopleListsRepository,
          PeopleListsRepository,
          PeopleListsRepository
        >
    with $Provider<PeopleListsRepository> {
  /// Repository for NIP-51 kind 30000 people lists.
  ///
  /// Wires the shared [NostrClient] (via [nostrServiceProvider]) into a
  /// [PeopleListsRepositoryImpl] backed by a [LocalPeopleListsCache] that opens
  /// a lazily-created `hive_ce` box named [_peopleListsBoxName]. The repository
  /// itself has no Flutter dependencies; this provider owns all UI glue.
  const PeopleListsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'peopleListsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$peopleListsRepositoryHash();

  @$internal
  @override
  $ProviderElement<PeopleListsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PeopleListsRepository create(Ref ref) {
    return peopleListsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PeopleListsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PeopleListsRepository>(value),
    );
  }
}

String _$peopleListsRepositoryHash() =>
    r'd62acfadef10fcaab46ba5f74352e7feacf3a63d';

/// Bookmark service for NIP-51 bookmarks

@ProviderFor(bookmarkService)
const bookmarkServiceProvider = BookmarkServiceProvider._();

/// Bookmark service for NIP-51 bookmarks

final class BookmarkServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookmarkService>,
          BookmarkService,
          FutureOr<BookmarkService>
        >
    with $FutureModifier<BookmarkService>, $FutureProvider<BookmarkService> {
  /// Bookmark service for NIP-51 bookmarks
  const BookmarkServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookmarkServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookmarkServiceHash();

  @$internal
  @override
  $FutureProviderElement<BookmarkService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookmarkService> create(Ref ref) {
    return bookmarkService(ref);
  }
}

String _$bookmarkServiceHash() => r'2430aa71f0c433b0c192fb434b3777877eb41a49';

/// Mute service for NIP-51 mute lists

@ProviderFor(muteService)
const muteServiceProvider = MuteServiceProvider._();

/// Mute service for NIP-51 mute lists

final class MuteServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<MuteService>,
          MuteService,
          FutureOr<MuteService>
        >
    with $FutureModifier<MuteService>, $FutureProvider<MuteService> {
  /// Mute service for NIP-51 mute lists
  const MuteServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'muteServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$muteServiceHash();

  @$internal
  @override
  $FutureProviderElement<MuteService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MuteService> create(Ref ref) {
    return muteService(ref);
  }
}

String _$muteServiceHash() => r'a7faf00b4fe5d420db0bff450d444db5aa5d4934';

/// Content deletion service for NIP-09 delete events

@ProviderFor(contentDeletionService)
const contentDeletionServiceProvider = ContentDeletionServiceProvider._();

/// Content deletion service for NIP-09 delete events

final class ContentDeletionServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentDeletionService>,
          ContentDeletionService,
          FutureOr<ContentDeletionService>
        >
    with
        $FutureModifier<ContentDeletionService>,
        $FutureProvider<ContentDeletionService> {
  /// Content deletion service for NIP-09 delete events
  const ContentDeletionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentDeletionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentDeletionServiceHash();

  @$internal
  @override
  $FutureProviderElement<ContentDeletionService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContentDeletionService> create(Ref ref) {
    return contentDeletionService(ref);
  }
}

String _$contentDeletionServiceHash() =>
    r'595760368d4f392891586c43959ceba01e02bcd5';

/// Bug report service for collecting diagnostics and sending encrypted reports

@ProviderFor(bugReportService)
const bugReportServiceProvider = BugReportServiceProvider._();

/// Bug report service for collecting diagnostics and sending encrypted reports

final class BugReportServiceProvider
    extends
        $FunctionalProvider<
          BugReportService,
          BugReportService,
          BugReportService
        >
    with $Provider<BugReportService> {
  /// Bug report service for collecting diagnostics and sending encrypted reports
  const BugReportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bugReportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bugReportServiceHash();

  @$internal
  @override
  $ProviderElement<BugReportService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BugReportService create(Ref ref) {
    return bugReportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BugReportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BugReportService>(value),
    );
  }
}

String _$bugReportServiceHash() => r'a243bf5fae16e223b148a829b14f9857af1c4592';

/// Provider for NIP-17 DM repository.
///
/// Creates a [DmRepository] that handles receiving, decrypting, persisting,
/// and sending encrypted direct messages. Works with any [NostrSigner]
/// (local keys, Keycast RPC, Amber, etc.).
///
/// Sets auth credentials eagerly so read/send operations work immediately,
/// then starts the gift-wrap subscription so DMs are ingested for the whole
/// authenticated session — not just while [InboxPage] is mounted (#2931).
///
/// Cold-start cost is bounded by two existing mechanisms that landed with
/// the original lazy-inbox work (#2766):
/// - The `since: newestSyncedAt - 2d` filter in [DmRepository.startListening]
///   limits the relay backlog to recent events on every open after the first.
/// - Decryption is offloaded to a background isolate via
///   `dm_decryption_worker.dart`, keeping the UI thread responsive.
///
/// Uses `keepAlive: true` because the repository must survive transient
/// dependency rebuilds (e.g. `nostrSessionProvider` readiness changes,
/// `nostrServiceProvider` auth-state changes).
///
/// Non-nullable: the repository works without keys at construction time.
/// Read operations return cached/empty data; write operations check keys.

@ProviderFor(dmRepository)
const dmRepositoryProvider = DmRepositoryProvider._();

/// Provider for NIP-17 DM repository.
///
/// Creates a [DmRepository] that handles receiving, decrypting, persisting,
/// and sending encrypted direct messages. Works with any [NostrSigner]
/// (local keys, Keycast RPC, Amber, etc.).
///
/// Sets auth credentials eagerly so read/send operations work immediately,
/// then starts the gift-wrap subscription so DMs are ingested for the whole
/// authenticated session — not just while [InboxPage] is mounted (#2931).
///
/// Cold-start cost is bounded by two existing mechanisms that landed with
/// the original lazy-inbox work (#2766):
/// - The `since: newestSyncedAt - 2d` filter in [DmRepository.startListening]
///   limits the relay backlog to recent events on every open after the first.
/// - Decryption is offloaded to a background isolate via
///   `dm_decryption_worker.dart`, keeping the UI thread responsive.
///
/// Uses `keepAlive: true` because the repository must survive transient
/// dependency rebuilds (e.g. `nostrSessionProvider` readiness changes,
/// `nostrServiceProvider` auth-state changes).
///
/// Non-nullable: the repository works without keys at construction time.
/// Read operations return cached/empty data; write operations check keys.

final class DmRepositoryProvider
    extends $FunctionalProvider<DmRepository, DmRepository, DmRepository>
    with $Provider<DmRepository> {
  /// Provider for NIP-17 DM repository.
  ///
  /// Creates a [DmRepository] that handles receiving, decrypting, persisting,
  /// and sending encrypted direct messages. Works with any [NostrSigner]
  /// (local keys, Keycast RPC, Amber, etc.).
  ///
  /// Sets auth credentials eagerly so read/send operations work immediately,
  /// then starts the gift-wrap subscription so DMs are ingested for the whole
  /// authenticated session — not just while [InboxPage] is mounted (#2931).
  ///
  /// Cold-start cost is bounded by two existing mechanisms that landed with
  /// the original lazy-inbox work (#2766):
  /// - The `since: newestSyncedAt - 2d` filter in [DmRepository.startListening]
  ///   limits the relay backlog to recent events on every open after the first.
  /// - Decryption is offloaded to a background isolate via
  ///   `dm_decryption_worker.dart`, keeping the UI thread responsive.
  ///
  /// Uses `keepAlive: true` because the repository must survive transient
  /// dependency rebuilds (e.g. `nostrSessionProvider` readiness changes,
  /// `nostrServiceProvider` auth-state changes).
  ///
  /// Non-nullable: the repository works without keys at construction time.
  /// Read operations return cached/empty data; write operations check keys.
  const DmRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dmRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dmRepositoryHash();

  @$internal
  @override
  $ProviderElement<DmRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DmRepository create(Ref ref) {
    return dmRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DmRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DmRepository>(value),
    );
  }
}

String _$dmRepositoryHash() => r'8e673c2c819f25d57a801bee40d3104534bfc682';

/// Provider for CommentsRepository instance
///
/// Creates a CommentsRepository for managing comments on events.
/// Viewing comments works without authentication.
/// Posting comments requires authentication (handled by AuthService in BLoC).
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)

@ProviderFor(commentsRepository)
const commentsRepositoryProvider = CommentsRepositoryProvider._();

/// Provider for CommentsRepository instance
///
/// Creates a CommentsRepository for managing comments on events.
/// Viewing comments works without authentication.
/// Posting comments requires authentication (handled by AuthService in BLoC).
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)

final class CommentsRepositoryProvider
    extends
        $FunctionalProvider<
          CommentsRepository,
          CommentsRepository,
          CommentsRepository
        >
    with $Provider<CommentsRepository> {
  /// Provider for CommentsRepository instance
  ///
  /// Creates a CommentsRepository for managing comments on events.
  /// Viewing comments works without authentication.
  /// Posting comments requires authentication (handled by AuthService in BLoC).
  ///
  /// Uses:
  /// - NostrClient from nostrServiceProvider (for relay communication)
  const CommentsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentsRepositoryHash();

  @$internal
  @override
  $ProviderElement<CommentsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CommentsRepository create(Ref ref) {
    return commentsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentsRepository>(value),
    );
  }
}

String _$commentsRepositoryHash() =>
    r'c93d13851e0a4299c19edc87d439f767237ecc72';
