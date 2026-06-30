// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Video filter builder for constructing relay-aware filters with server-side sorting

@ProviderFor(videoFilterBuilder)
final videoFilterBuilderProvider = VideoFilterBuilderProvider._();

/// Video filter builder for constructing relay-aware filters with server-side sorting

final class VideoFilterBuilderProvider
    extends
        $FunctionalProvider<
          VideoFilterBuilder,
          VideoFilterBuilder,
          VideoFilterBuilder
        >
    with $Provider<VideoFilterBuilder> {
  /// Video filter builder for constructing relay-aware filters with server-side sorting
  VideoFilterBuilderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoFilterBuilderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoFilterBuilderHash();

  @$internal
  @override
  $ProviderElement<VideoFilterBuilder> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoFilterBuilder create(Ref ref) {
    return videoFilterBuilder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoFilterBuilder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoFilterBuilder>(value),
    );
  }
}

String _$videoFilterBuilderHash() =>
    r'fa2390a9274ddcc619886531d6cfa0671b545d1a';

/// Personal event cache service for ALL user's own events

@ProviderFor(personalEventCacheService)
final personalEventCacheServiceProvider = PersonalEventCacheServiceProvider._();

/// Personal event cache service for ALL user's own events

final class PersonalEventCacheServiceProvider
    extends
        $FunctionalProvider<
          PersonalEventCacheService,
          PersonalEventCacheService,
          PersonalEventCacheService
        >
    with $Provider<PersonalEventCacheService> {
  /// Personal event cache service for ALL user's own events
  PersonalEventCacheServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalEventCacheServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalEventCacheServiceHash();

  @$internal
  @override
  $ProviderElement<PersonalEventCacheService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PersonalEventCacheService create(Ref ref) {
    return personalEventCacheService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersonalEventCacheService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersonalEventCacheService>(value),
    );
  }
}

String _$personalEventCacheServiceHash() =>
    r'f8fbeaaa8db79abff62ce85e3ca683320c5f0e50';

/// Seen videos service for tracking viewed content

@ProviderFor(seenVideosService)
final seenVideosServiceProvider = SeenVideosServiceProvider._();

/// Seen videos service for tracking viewed content

final class SeenVideosServiceProvider
    extends
        $FunctionalProvider<
          SeenVideosService,
          SeenVideosService,
          SeenVideosService
        >
    with $Provider<SeenVideosService> {
  /// Seen videos service for tracking viewed content
  SeenVideosServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seenVideosServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seenVideosServiceHash();

  @$internal
  @override
  $ProviderElement<SeenVideosService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SeenVideosService create(Ref ref) {
    return seenVideosService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SeenVideosService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SeenVideosService>(value),
    );
  }
}

String _$seenVideosServiceHash() => r'74099bd4d859b446a3fc0cf1a7f416756a104e43';

/// Subscription manager for centralized subscription management

@ProviderFor(subscriptionManager)
final subscriptionManagerProvider = SubscriptionManagerProvider._();

/// Subscription manager for centralized subscription management

final class SubscriptionManagerProvider
    extends
        $FunctionalProvider<
          SubscriptionManager,
          SubscriptionManager,
          SubscriptionManager
        >
    with $Provider<SubscriptionManager> {
  /// Subscription manager for centralized subscription management
  SubscriptionManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionManagerHash();

  @$internal
  @override
  $ProviderElement<SubscriptionManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubscriptionManager create(Ref ref) {
    return subscriptionManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubscriptionManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubscriptionManager>(value),
    );
  }
}

String _$subscriptionManagerHash() =>
    r'b65a6978927d3004c6f841e0b80075f9db9645d2';

/// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager

@ProviderFor(videoEventService)
final videoEventServiceProvider = VideoEventServiceProvider._();

/// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager

final class VideoEventServiceProvider
    extends
        $FunctionalProvider<
          VideoEventService,
          VideoEventService,
          VideoEventService
        >
    with $Provider<VideoEventService> {
  /// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager
  VideoEventServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventServiceHash();

  @$internal
  @override
  $ProviderElement<VideoEventService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoEventService create(Ref ref) {
    return videoEventService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoEventService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoEventService>(value),
    );
  }
}

String _$videoEventServiceHash() => r'9795e17f42ef25c2af8e036b10ca4e043babf179';

/// Video event publisher for publishing video events to Nostr relays

@ProviderFor(videoEventPublisher)
final videoEventPublisherProvider = VideoEventPublisherProvider._();

/// Video event publisher for publishing video events to Nostr relays

final class VideoEventPublisherProvider
    extends
        $FunctionalProvider<
          VideoEventPublisher,
          VideoEventPublisher,
          VideoEventPublisher
        >
    with $Provider<VideoEventPublisher> {
  /// Video event publisher for publishing video events to Nostr relays
  VideoEventPublisherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventPublisherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventPublisherHash();

  @$internal
  @override
  $ProviderElement<VideoEventPublisher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoEventPublisher create(Ref ref) {
    return videoEventPublisher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoEventPublisher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoEventPublisher>(value),
    );
  }
}

String _$videoEventPublisherHash() =>
    r'efa59c22d7b675684e4c3f7d203768fc2df5eefc';

/// View event publisher for kind 22236 ephemeral analytics events
///
/// Publishes video view events to track watch time, traffic sources,
/// and enable creator analytics and recommendation systems.

@ProviderFor(viewEventPublisher)
final viewEventPublisherProvider = ViewEventPublisherProvider._();

/// View event publisher for kind 22236 ephemeral analytics events
///
/// Publishes video view events to track watch time, traffic sources,
/// and enable creator analytics and recommendation systems.

final class ViewEventPublisherProvider
    extends
        $FunctionalProvider<
          ViewEventPublisher,
          ViewEventPublisher,
          ViewEventPublisher
        >
    with $Provider<ViewEventPublisher> {
  /// View event publisher for kind 22236 ephemeral analytics events
  ///
  /// Publishes video view events to track watch time, traffic sources,
  /// and enable creator analytics and recommendation systems.
  ViewEventPublisherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewEventPublisherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewEventPublisherHash();

  @$internal
  @override
  $ProviderElement<ViewEventPublisher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ViewEventPublisher create(Ref ref) {
    return viewEventPublisher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewEventPublisher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewEventPublisher>(value),
    );
  }
}

String _$viewEventPublisherHash() =>
    r'33477998370aad03ce25bb4beff38a28da291d64';

/// Subscribed list video cache for merging subscribed list videos into home feed
/// Depends on CuratedListService which is async, so watch the state provider

@ProviderFor(subscribedListVideoCache)
final subscribedListVideoCacheProvider = SubscribedListVideoCacheProvider._();

/// Subscribed list video cache for merging subscribed list videos into home feed
/// Depends on CuratedListService which is async, so watch the state provider

final class SubscribedListVideoCacheProvider
    extends
        $FunctionalProvider<
          SubscribedListVideoCache?,
          SubscribedListVideoCache?,
          SubscribedListVideoCache?
        >
    with $Provider<SubscribedListVideoCache?> {
  /// Subscribed list video cache for merging subscribed list videos into home feed
  /// Depends on CuratedListService which is async, so watch the state provider
  SubscribedListVideoCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscribedListVideoCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscribedListVideoCacheHash();

  @$internal
  @override
  $ProviderElement<SubscribedListVideoCache?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubscribedListVideoCache? create(Ref ref) {
    return subscribedListVideoCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubscribedListVideoCache? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubscribedListVideoCache?>(value),
    );
  }
}

String _$subscribedListVideoCacheHash() =>
    r'e7d9c2f15e09ab7d3848597e7d288749e3050f08';

/// Video sharing service
///
/// When a [DmRepository] is available the service sends videos via NIP-17
/// encrypted DMs (NIP-17). Otherwise falls back to NIP-04 kind 4.

@ProviderFor(videoSharingService)
final videoSharingServiceProvider = VideoSharingServiceProvider._();

/// Video sharing service
///
/// When a [DmRepository] is available the service sends videos via NIP-17
/// encrypted DMs (NIP-17). Otherwise falls back to NIP-04 kind 4.

final class VideoSharingServiceProvider
    extends
        $FunctionalProvider<
          VideoSharingService?,
          VideoSharingService?,
          VideoSharingService?
        >
    with $Provider<VideoSharingService?> {
  /// Video sharing service
  ///
  /// When a [DmRepository] is available the service sends videos via NIP-17
  /// encrypted DMs (NIP-17). Otherwise falls back to NIP-04 kind 4.
  VideoSharingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoSharingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoSharingServiceHash();

  @$internal
  @override
  $ProviderElement<VideoSharingService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoSharingService? create(Ref ref) {
    return videoSharingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoSharingService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoSharingService?>(value),
    );
  }
}

String _$videoSharingServiceHash() =>
    r'c67ca5b381903ab2a6d29bc2f64e057661279598';

/// Unified resolver for fetching a [VideoEvent] by its event id, with
/// in-memory → personal cache → relay fallback. See [VideoEventResolver].

@ProviderFor(videoEventResolver)
final videoEventResolverProvider = VideoEventResolverProvider._();

/// Unified resolver for fetching a [VideoEvent] by its event id, with
/// in-memory → personal cache → relay fallback. See [VideoEventResolver].

final class VideoEventResolverProvider
    extends
        $FunctionalProvider<
          VideoEventResolver,
          VideoEventResolver,
          VideoEventResolver
        >
    with $Provider<VideoEventResolver> {
  /// Unified resolver for fetching a [VideoEvent] by its event id, with
  /// in-memory → personal cache → relay fallback. See [VideoEventResolver].
  VideoEventResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventResolverHash();

  @$internal
  @override
  $ProviderElement<VideoEventResolver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoEventResolver create(Ref ref) {
    return videoEventResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoEventResolver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoEventResolver>(value),
    );
  }
}

String _$videoEventResolverHash() =>
    r'a076181f7238f6f3cb91443d714872abb5805ee0';

/// Service that orchestrates the video-metadata-edit republish flow.

@ProviderFor(videoMetadataUpdateService)
final videoMetadataUpdateServiceProvider =
    VideoMetadataUpdateServiceProvider._();

/// Service that orchestrates the video-metadata-edit republish flow.

final class VideoMetadataUpdateServiceProvider
    extends
        $FunctionalProvider<
          VideoMetadataUpdateService,
          VideoMetadataUpdateService,
          VideoMetadataUpdateService
        >
    with $Provider<VideoMetadataUpdateService> {
  /// Service that orchestrates the video-metadata-edit republish flow.
  VideoMetadataUpdateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoMetadataUpdateServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoMetadataUpdateServiceHash();

  @$internal
  @override
  $ProviderElement<VideoMetadataUpdateService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoMetadataUpdateService create(Ref ref) {
    return videoMetadataUpdateService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoMetadataUpdateService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoMetadataUpdateService>(value),
    );
  }
}

String _$videoMetadataUpdateServiceHash() =>
    r'411d6327e9cdd7e14c307357ac64d337d52dc99d';

/// Broken video tracker service for filtering non-functional videos

@ProviderFor(brokenVideoTracker)
final brokenVideoTrackerProvider = BrokenVideoTrackerProvider._();

/// Broken video tracker service for filtering non-functional videos

final class BrokenVideoTrackerProvider
    extends
        $FunctionalProvider<
          AsyncValue<BrokenVideoTracker>,
          BrokenVideoTracker,
          FutureOr<BrokenVideoTracker>
        >
    with
        $FutureModifier<BrokenVideoTracker>,
        $FutureProvider<BrokenVideoTracker> {
  /// Broken video tracker service for filtering non-functional videos
  BrokenVideoTrackerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brokenVideoTrackerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brokenVideoTrackerHash();

  @$internal
  @override
  $FutureProviderElement<BrokenVideoTracker> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BrokenVideoTracker> create(Ref ref) {
    return brokenVideoTracker(ref);
  }
}

String _$brokenVideoTrackerHash() =>
    r'36268bd477659a229f13da325ac23403a20e7fa7';

/// Provider for VideoLocalStorage instance (SQLite-backed)
///
/// Creates a DbVideoLocalStorage for caching video events locally.
/// Used by VideosRepository for cache-first lookups.
///
/// Uses:
/// - NostrEventsDao from databaseProvider (for SQLite storage)

@ProviderFor(videoLocalStorage)
final videoLocalStorageProvider = VideoLocalStorageProvider._();

/// Provider for VideoLocalStorage instance (SQLite-backed)
///
/// Creates a DbVideoLocalStorage for caching video events locally.
/// Used by VideosRepository for cache-first lookups.
///
/// Uses:
/// - NostrEventsDao from databaseProvider (for SQLite storage)

final class VideoLocalStorageProvider
    extends
        $FunctionalProvider<
          VideoLocalStorage,
          VideoLocalStorage,
          VideoLocalStorage
        >
    with $Provider<VideoLocalStorage> {
  /// Provider for VideoLocalStorage instance (SQLite-backed)
  ///
  /// Creates a DbVideoLocalStorage for caching video events locally.
  /// Used by VideosRepository for cache-first lookups.
  ///
  /// Uses:
  /// - NostrEventsDao from databaseProvider (for SQLite storage)
  VideoLocalStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoLocalStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoLocalStorageHash();

  @$internal
  @override
  $ProviderElement<VideoLocalStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoLocalStorage create(Ref ref) {
    return videoLocalStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoLocalStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoLocalStorage>(value),
    );
  }
}

String _$videoLocalStorageHash() => r'0be44203ec8edf59105a013aae374c07637a3ba0';

/// Provider for VideosRepository instance
///
/// Creates a VideosRepository for loading video feeds with pagination.
/// Works without authentication for public feeds.
///
/// Rebuilds (yielding a fresh in-memory cache) when content filter, aspect
/// ratio, or Divine-host filter preferences change. The version providers
/// act as rebuild triggers since the underlying services are long-lived
/// ChangeNotifiers that don't themselves cause provider invalidation.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - VideoLocalStorage for cache-first lookups and caching results
/// - ContentBlocklistRepository for filtering blocked/muted users
/// - ContentFilterService for filtering NSFW content based on user preferences
/// - FunnelcakeApiClient for trending/popular video sorting

@ProviderFor(videosRepository)
final videosRepositoryProvider = VideosRepositoryProvider._();

/// Provider for VideosRepository instance
///
/// Creates a VideosRepository for loading video feeds with pagination.
/// Works without authentication for public feeds.
///
/// Rebuilds (yielding a fresh in-memory cache) when content filter, aspect
/// ratio, or Divine-host filter preferences change. The version providers
/// act as rebuild triggers since the underlying services are long-lived
/// ChangeNotifiers that don't themselves cause provider invalidation.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - VideoLocalStorage for cache-first lookups and caching results
/// - ContentBlocklistRepository for filtering blocked/muted users
/// - ContentFilterService for filtering NSFW content based on user preferences
/// - FunnelcakeApiClient for trending/popular video sorting

final class VideosRepositoryProvider
    extends
        $FunctionalProvider<
          VideosRepository,
          VideosRepository,
          VideosRepository
        >
    with $Provider<VideosRepository> {
  /// Provider for VideosRepository instance
  ///
  /// Creates a VideosRepository for loading video feeds with pagination.
  /// Works without authentication for public feeds.
  ///
  /// Rebuilds (yielding a fresh in-memory cache) when content filter, aspect
  /// ratio, or Divine-host filter preferences change. The version providers
  /// act as rebuild triggers since the underlying services are long-lived
  /// ChangeNotifiers that don't themselves cause provider invalidation.
  ///
  /// Uses:
  /// - NostrClient from nostrServiceProvider (for relay communication)
  /// - VideoLocalStorage for cache-first lookups and caching results
  /// - ContentBlocklistRepository for filtering blocked/muted users
  /// - ContentFilterService for filtering NSFW content based on user preferences
  /// - FunnelcakeApiClient for trending/popular video sorting
  VideosRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videosRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videosRepositoryHash();

  @$internal
  @override
  $ProviderElement<VideosRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VideosRepository create(Ref ref) {
    return videosRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideosRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideosRepository>(value),
    );
  }
}

String _$videosRepositoryHash() => r'e4ef1b585f6dc5a957af569cd01f750e60ba5838';

/// Provider for LikesRepository instance
///
/// Creates a LikesRepository when the user is authenticated.
/// Returns null when user is not authenticated.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalReactionsDao from databaseProvider (for local storage)

@ProviderFor(likesRepository)
final likesRepositoryProvider = LikesRepositoryProvider._();

/// Provider for LikesRepository instance
///
/// Creates a LikesRepository when the user is authenticated.
/// Returns null when user is not authenticated.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalReactionsDao from databaseProvider (for local storage)

final class LikesRepositoryProvider
    extends
        $FunctionalProvider<LikesRepository, LikesRepository, LikesRepository>
    with $Provider<LikesRepository> {
  /// Provider for LikesRepository instance
  ///
  /// Creates a LikesRepository when the user is authenticated.
  /// Returns null when user is not authenticated.
  ///
  /// Uses:
  /// - NostrClient from nostrServiceProvider (for relay communication)
  /// - PersonalReactionsDao from databaseProvider (for local storage)
  LikesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'likesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$likesRepositoryHash();

  @$internal
  @override
  $ProviderElement<LikesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LikesRepository create(Ref ref) {
    return likesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LikesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LikesRepository>(value),
    );
  }
}

String _$likesRepositoryHash() => r'fc6229af119fdde9c92deaa2280f26e3ce3bfb00';
