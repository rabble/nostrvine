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

/// Video filter builder for constructing relay-aware filters with server-side sorting

@ProviderFor(videoFilterBuilder)
const videoFilterBuilderProvider = VideoFilterBuilderProvider._();

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
  const VideoFilterBuilderProvider._()
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

/// Video visibility manager for controlling video playback based on visibility

@ProviderFor(videoVisibilityManager)
const videoVisibilityManagerProvider = VideoVisibilityManagerProvider._();

/// Video visibility manager for controlling video playback based on visibility

final class VideoVisibilityManagerProvider
    extends
        $FunctionalProvider<
          VideoVisibilityManager,
          VideoVisibilityManager,
          VideoVisibilityManager
        >
    with $Provider<VideoVisibilityManager> {
  /// Video visibility manager for controlling video playback based on visibility
  const VideoVisibilityManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoVisibilityManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoVisibilityManagerHash();

  @$internal
  @override
  $ProviderElement<VideoVisibilityManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoVisibilityManager create(Ref ref) {
    return videoVisibilityManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoVisibilityManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoVisibilityManager>(value),
    );
  }
}

String _$videoVisibilityManagerHash() =>
    r'e1a7642e6cb5e4c1733981be738064df7c3c0a91';

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

/// Secure key storage service (foundational service)

@ProviderFor(secureKeyStorage)
const secureKeyStorageProvider = SecureKeyStorageProvider._();

/// Secure key storage service (foundational service)

final class SecureKeyStorageProvider
    extends
        $FunctionalProvider<
          SecureKeyStorage,
          SecureKeyStorage,
          SecureKeyStorage
        >
    with $Provider<SecureKeyStorage> {
  /// Secure key storage service (foundational service)
  const SecureKeyStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureKeyStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureKeyStorageHash();

  @$internal
  @override
  $ProviderElement<SecureKeyStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecureKeyStorage create(Ref ref) {
    return secureKeyStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureKeyStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureKeyStorage>(value),
    );
  }
}

String _$secureKeyStorageHash() => r'853547d439994307884d2f47f3d9769daa0a1e96';

@ProviderFor(oauthConfig)
const oauthConfigProvider = OauthConfigProvider._();

final class OauthConfigProvider
    extends $FunctionalProvider<OAuthConfig, OAuthConfig, OAuthConfig>
    with $Provider<OAuthConfig> {
  const OauthConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oauthConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oauthConfigHash();

  @$internal
  @override
  $ProviderElement<OAuthConfig> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OAuthConfig create(Ref ref) {
    return oauthConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OAuthConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OAuthConfig>(value),
    );
  }
}

String _$oauthConfigHash() => r'2078bce919b9216a65dedc105d471568ba510a52';

@ProviderFor(flutterSecureStorage)
const flutterSecureStorageProvider = FlutterSecureStorageProvider._();

final class FlutterSecureStorageProvider
    extends
        $FunctionalProvider<
          FlutterSecureStorage,
          FlutterSecureStorage,
          FlutterSecureStorage
        >
    with $Provider<FlutterSecureStorage> {
  const FlutterSecureStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'flutterSecureStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$flutterSecureStorageHash();

  @$internal
  @override
  $ProviderElement<FlutterSecureStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FlutterSecureStorage create(Ref ref) {
    return flutterSecureStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlutterSecureStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlutterSecureStorage>(value),
    );
  }
}

String _$flutterSecureStorageHash() =>
    r'3e701848e4daaf6a76caf444539af06b4c9d4d9b';

@ProviderFor(secureKeycastStorage)
const secureKeycastStorageProvider = SecureKeycastStorageProvider._();

final class SecureKeycastStorageProvider
    extends
        $FunctionalProvider<
          SecureKeycastStorage,
          SecureKeycastStorage,
          SecureKeycastStorage
        >
    with $Provider<SecureKeycastStorage> {
  const SecureKeycastStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureKeycastStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureKeycastStorageHash();

  @$internal
  @override
  $ProviderElement<SecureKeycastStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SecureKeycastStorage create(Ref ref) {
    return secureKeycastStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureKeycastStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureKeycastStorage>(value),
    );
  }
}

String _$secureKeycastStorageHash() =>
    r'c57c0ec02e36cd1a0cc8b850c450af2eb4c496b3';

@ProviderFor(pendingVerificationService)
const pendingVerificationServiceProvider =
    PendingVerificationServiceProvider._();

final class PendingVerificationServiceProvider
    extends
        $FunctionalProvider<
          PendingVerificationService,
          PendingVerificationService,
          PendingVerificationService
        >
    with $Provider<PendingVerificationService> {
  const PendingVerificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingVerificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingVerificationServiceHash();

  @$internal
  @override
  $ProviderElement<PendingVerificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PendingVerificationService create(Ref ref) {
    return pendingVerificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingVerificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingVerificationService>(value),
    );
  }
}

String _$pendingVerificationServiceHash() =>
    r'9b524b7d7fd20c98b2e0942e9ea6358419dc9dd4';

@ProviderFor(oauthClient)
const oauthClientProvider = OauthClientProvider._();

final class OauthClientProvider
    extends $FunctionalProvider<KeycastOAuth, KeycastOAuth, KeycastOAuth>
    with $Provider<KeycastOAuth> {
  const OauthClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oauthClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oauthClientHash();

  @$internal
  @override
  $ProviderElement<KeycastOAuth> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KeycastOAuth create(Ref ref) {
    return oauthClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KeycastOAuth value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KeycastOAuth>(value),
    );
  }
}

String _$oauthClientHash() => r'0cc53348fbc3c769c81e52dd200c0efc6c20de3c';

@ProviderFor(passwordResetListener)
const passwordResetListenerProvider = PasswordResetListenerProvider._();

final class PasswordResetListenerProvider
    extends
        $FunctionalProvider<
          PasswordResetListener,
          PasswordResetListener,
          PasswordResetListener
        >
    with $Provider<PasswordResetListener> {
  const PasswordResetListenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'passwordResetListenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$passwordResetListenerHash();

  @$internal
  @override
  $ProviderElement<PasswordResetListener> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PasswordResetListener create(Ref ref) {
    return passwordResetListener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PasswordResetListener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PasswordResetListener>(value),
    );
  }
}

String _$passwordResetListenerHash() =>
    r'3fe0dd6870cd754567aaaf53b5b74f439f232ad4';

@ProviderFor(emailVerificationListener)
const emailVerificationListenerProvider = EmailVerificationListenerProvider._();

final class EmailVerificationListenerProvider
    extends
        $FunctionalProvider<
          EmailVerificationListener,
          EmailVerificationListener,
          EmailVerificationListener
        >
    with $Provider<EmailVerificationListener> {
  const EmailVerificationListenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailVerificationListenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailVerificationListenerHash();

  @$internal
  @override
  $ProviderElement<EmailVerificationListener> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EmailVerificationListener create(Ref ref) {
    return emailVerificationListener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmailVerificationListener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmailVerificationListener>(value),
    );
  }
}

String _$emailVerificationListenerHash() =>
    r'3ddc56da4619f64800573667612a6fa9af75395e';

/// Web authentication service (for web platform only)

@ProviderFor(webAuthService)
const webAuthServiceProvider = WebAuthServiceProvider._();

/// Web authentication service (for web platform only)

final class WebAuthServiceProvider
    extends $FunctionalProvider<WebAuthService, WebAuthService, WebAuthService>
    with $Provider<WebAuthService> {
  /// Web authentication service (for web platform only)
  const WebAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webAuthServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webAuthServiceHash();

  @$internal
  @override
  $ProviderElement<WebAuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WebAuthService create(Ref ref) {
    return webAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebAuthService>(value),
    );
  }
}

String _$webAuthServiceHash() => r'53411c0f6a62bb9b59f90a0d7fc738a553a0b575';

/// Nostr key manager for cryptographic operations

@ProviderFor(nostrKeyManager)
const nostrKeyManagerProvider = NostrKeyManagerProvider._();

/// Nostr key manager for cryptographic operations

final class NostrKeyManagerProvider
    extends
        $FunctionalProvider<NostrKeyManager, NostrKeyManager, NostrKeyManager>
    with $Provider<NostrKeyManager> {
  /// Nostr key manager for cryptographic operations
  const NostrKeyManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nostrKeyManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nostrKeyManagerHash();

  @$internal
  @override
  $ProviderElement<NostrKeyManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NostrKeyManager create(Ref ref) {
    return nostrKeyManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NostrKeyManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NostrKeyManager>(value),
    );
  }
}

String _$nostrKeyManagerHash() => r'a0d67b6d79af5ecdc42bc6616542249200a24b64';

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

/// Personal event cache service for ALL user's own events

@ProviderFor(personalEventCacheService)
const personalEventCacheServiceProvider = PersonalEventCacheServiceProvider._();

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
  const PersonalEventCacheServiceProvider._()
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
    r'72d305468d4e52c2b92b093fa583cb8b1ba20a29';

/// Seen videos service for tracking viewed content

@ProviderFor(seenVideosService)
const seenVideosServiceProvider = SeenVideosServiceProvider._();

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
  const SeenVideosServiceProvider._()
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

/// Authentication service

@ProviderFor(authService)
const authServiceProvider = AuthServiceProvider._();

/// Authentication service

final class AuthServiceProvider
    extends $FunctionalProvider<AuthService, AuthService, AuthService>
    with $Provider<AuthService> {
  /// Authentication service
  const AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $ProviderElement<AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthService create(Ref ref) {
    return authService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthService>(value),
    );
  }
}

String _$authServiceHash() => r'5ed8b2e4f69b956cef94207839973aa1f676df4c';

/// Provider that returns current auth state and rebuilds when it changes.
/// Widgets should watch this instead of authService.authState directly
/// to get automatic rebuilds when authentication state changes.

@ProviderFor(currentAuthState)
const currentAuthStateProvider = CurrentAuthStateProvider._();

/// Provider that returns current auth state and rebuilds when it changes.
/// Widgets should watch this instead of authService.authState directly
/// to get automatic rebuilds when authentication state changes.

final class CurrentAuthStateProvider
    extends $FunctionalProvider<AuthState, AuthState, AuthState>
    with $Provider<AuthState> {
  /// Provider that returns current auth state and rebuilds when it changes.
  /// Widgets should watch this instead of authService.authState directly
  /// to get automatic rebuilds when authentication state changes.
  const CurrentAuthStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAuthStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAuthStateHash();

  @$internal
  @override
  $ProviderElement<AuthState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthState create(Ref ref) {
    return currentAuthState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$currentAuthStateHash() => r'41c987ffc8f661555bab3ebec9078180411f66eb';

/// Provider that returns current RPC capability and rebuilds on changes.
///
/// Widgets and repositories should watch this instead of polling
/// [AuthService.authRpcCapability] directly.

@ProviderFor(currentAuthRpcCapability)
const currentAuthRpcCapabilityProvider = CurrentAuthRpcCapabilityProvider._();

/// Provider that returns current RPC capability and rebuilds on changes.
///
/// Widgets and repositories should watch this instead of polling
/// [AuthService.authRpcCapability] directly.

final class CurrentAuthRpcCapabilityProvider
    extends
        $FunctionalProvider<
          AuthRpcCapability,
          AuthRpcCapability,
          AuthRpcCapability
        >
    with $Provider<AuthRpcCapability> {
  /// Provider that returns current RPC capability and rebuilds on changes.
  ///
  /// Widgets and repositories should watch this instead of polling
  /// [AuthService.authRpcCapability] directly.
  const CurrentAuthRpcCapabilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAuthRpcCapabilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAuthRpcCapabilityHash();

  @$internal
  @override
  $ProviderElement<AuthRpcCapability> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AuthRpcCapability create(Ref ref) {
    return currentAuthRpcCapability(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRpcCapability value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRpcCapability>(value),
    );
  }
}

String _$currentAuthRpcCapabilityHash() =>
    r'cb273f3377e25d0c88104df14a38d2b502c3f7de';

/// Provider that fetches the list of known accounts from the auth service.
///
/// Invalidate this provider after sign-in or sign-out to refresh the list.

@ProviderFor(knownAccounts)
const knownAccountsProvider = KnownAccountsProvider._();

/// Provider that fetches the list of known accounts from the auth service.
///
/// Invalidate this provider after sign-in or sign-out to refresh the list.

final class KnownAccountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<KnownAccount>>,
          List<KnownAccount>,
          FutureOr<List<KnownAccount>>
        >
    with
        $FutureModifier<List<KnownAccount>>,
        $FutureProvider<List<KnownAccount>> {
  /// Provider that fetches the list of known accounts from the auth service.
  ///
  /// Invalidate this provider after sign-in or sign-out to refresh the list.
  const KnownAccountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownAccountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownAccountsHash();

  @$internal
  @override
  $FutureProviderElement<List<KnownAccount>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<KnownAccount>> create(Ref ref) {
    return knownAccounts(ref);
  }
}

String _$knownAccountsHash() => r'8e9753265420cf092af04aa07686c98cdaa8eb1e';

/// Provider that sets Zendesk user identity when auth state changes
/// Watch this provider at app startup to keep Zendesk identity in sync with auth

@ProviderFor(zendeskIdentitySync)
const zendeskIdentitySyncProvider = ZendeskIdentitySyncProvider._();

/// Provider that sets Zendesk user identity when auth state changes
/// Watch this provider at app startup to keep Zendesk identity in sync with auth

final class ZendeskIdentitySyncProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Provider that sets Zendesk user identity when auth state changes
  /// Watch this provider at app startup to keep Zendesk identity in sync with auth
  const ZendeskIdentitySyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zendeskIdentitySyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zendeskIdentitySyncHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return zendeskIdentitySync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$zendeskIdentitySyncHash() =>
    r'e49d4f9cedf56ec4131b30a6f1d9d45dada68bed';

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

/// Subscription manager for centralized subscription management

@ProviderFor(subscriptionManager)
const subscriptionManagerProvider = SubscriptionManagerProvider._();

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
  const SubscriptionManagerProvider._()
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
const videoEventServiceProvider = VideoEventServiceProvider._();

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
  const VideoEventServiceProvider._()
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

String _$videoEventServiceHash() => r'5a204c44e3372e78a32beaa8121f28df4121f54a';

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
    r'230cebbd57db166644b05510b23987fe7fa5547e';

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

/// Provider for [VerifierClient] pointed at the current environment's
/// verifier base URL. Stateless — every call hits the network.

@ProviderFor(verifierClient)
const verifierClientProvider = VerifierClientProvider._();

/// Provider for [VerifierClient] pointed at the current environment's
/// verifier base URL. Stateless — every call hits the network.

final class VerifierClientProvider
    extends $FunctionalProvider<VerifierClient, VerifierClient, VerifierClient>
    with $Provider<VerifierClient> {
  /// Provider for [VerifierClient] pointed at the current environment's
  /// verifier base URL. Stateless — every call hits the network.
  const VerifierClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'verifierClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$verifierClientHash();

  @$internal
  @override
  $ProviderElement<VerifierClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VerifierClient create(Ref ref) {
    return verifierClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VerifierClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VerifierClient>(value),
    );
  }
}

String _$verifierClientHash() => r'1d6966c5483814cd7fa203e7e9e198dc5c9c232d';

/// Provider for [IdentityClaimsRepository] composing the verifier client
/// with NIP-39 i tag parsing.

@ProviderFor(identityClaimsRepository)
const identityClaimsRepositoryProvider = IdentityClaimsRepositoryProvider._();

/// Provider for [IdentityClaimsRepository] composing the verifier client
/// with NIP-39 i tag parsing.

final class IdentityClaimsRepositoryProvider
    extends
        $FunctionalProvider<
          IdentityClaimsRepository,
          IdentityClaimsRepository,
          IdentityClaimsRepository
        >
    with $Provider<IdentityClaimsRepository> {
  /// Provider for [IdentityClaimsRepository] composing the verifier client
  /// with NIP-39 i tag parsing.
  const IdentityClaimsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'identityClaimsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$identityClaimsRepositoryHash();

  @$internal
  @override
  $ProviderElement<IdentityClaimsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IdentityClaimsRepository create(Ref ref) {
    return identityClaimsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IdentityClaimsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IdentityClaimsRepository>(value),
    );
  }
}

String _$identityClaimsRepositoryHash() =>
    r'451c65b551cddcf8cf2ef3d23ac862ab0ae1441d';

/// NIP-98 authentication service

@ProviderFor(nip98AuthService)
const nip98AuthServiceProvider = Nip98AuthServiceProvider._();

/// NIP-98 authentication service

final class Nip98AuthServiceProvider
    extends
        $FunctionalProvider<
          Nip98AuthService,
          Nip98AuthService,
          Nip98AuthService
        >
    with $Provider<Nip98AuthService> {
  /// NIP-98 authentication service
  const Nip98AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nip98AuthServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nip98AuthServiceHash();

  @$internal
  @override
  $ProviderElement<Nip98AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Nip98AuthService create(Ref ref) {
    return nip98AuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Nip98AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Nip98AuthService>(value),
    );
  }
}

String _$nip98AuthServiceHash() => r'cfc2e0a65e1dbd9c559886929257fa66a7afb1c6';

/// Blossom BUD-01 authentication service for age-restricted content

@ProviderFor(blossomAuthService)
const blossomAuthServiceProvider = BlossomAuthServiceProvider._();

/// Blossom BUD-01 authentication service for age-restricted content

final class BlossomAuthServiceProvider
    extends
        $FunctionalProvider<
          BlossomAuthService,
          BlossomAuthService,
          BlossomAuthService
        >
    with $Provider<BlossomAuthService> {
  /// Blossom BUD-01 authentication service for age-restricted content
  const BlossomAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blossomAuthServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blossomAuthServiceHash();

  @$internal
  @override
  $ProviderElement<BlossomAuthService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BlossomAuthService create(Ref ref) {
    return blossomAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlossomAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlossomAuthService>(value),
    );
  }
}

String _$blossomAuthServiceHash() =>
    r'18b397ce487844dd002ada34930c6ce08f0566f8';

/// Media authentication interceptor for handling 401 unauthorized responses

@ProviderFor(mediaAuthInterceptor)
const mediaAuthInterceptorProvider = MediaAuthInterceptorProvider._();

/// Media authentication interceptor for handling 401 unauthorized responses

final class MediaAuthInterceptorProvider
    extends
        $FunctionalProvider<
          MediaAuthInterceptor,
          MediaAuthInterceptor,
          MediaAuthInterceptor
        >
    with $Provider<MediaAuthInterceptor> {
  /// Media authentication interceptor for handling 401 unauthorized responses
  const MediaAuthInterceptorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaAuthInterceptorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaAuthInterceptorHash();

  @$internal
  @override
  $ProviderElement<MediaAuthInterceptor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MediaAuthInterceptor create(Ref ref) {
    return mediaAuthInterceptor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaAuthInterceptor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaAuthInterceptor>(value),
    );
  }
}

String _$mediaAuthInterceptorHash() =>
    r'91168d3b391f9274691b22a7c376b1a11ba98833';

/// Blossom upload service (uses user-configured Blossom server)

@ProviderFor(blossomUploadService)
const blossomUploadServiceProvider = BlossomUploadServiceProvider._();

/// Blossom upload service (uses user-configured Blossom server)

final class BlossomUploadServiceProvider
    extends
        $FunctionalProvider<
          BlossomUploadService,
          BlossomUploadService,
          BlossomUploadService
        >
    with $Provider<BlossomUploadService> {
  /// Blossom upload service (uses user-configured Blossom server)
  const BlossomUploadServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blossomUploadServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blossomUploadServiceHash();

  @$internal
  @override
  $ProviderElement<BlossomUploadService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BlossomUploadService create(Ref ref) {
    return blossomUploadService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlossomUploadService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlossomUploadService>(value),
    );
  }
}

String _$blossomUploadServiceHash() =>
    r'8b83e68824cc146d304111a8d88e5ea8fadb2cc7';

/// Upload manager uses only Blossom upload service

@ProviderFor(uploadManager)
const uploadManagerProvider = UploadManagerProvider._();

/// Upload manager uses only Blossom upload service

final class UploadManagerProvider
    extends $FunctionalProvider<UploadManager, UploadManager, UploadManager>
    with $Provider<UploadManager> {
  /// Upload manager uses only Blossom upload service
  const UploadManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uploadManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uploadManagerHash();

  @$internal
  @override
  $ProviderElement<UploadManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UploadManager create(Ref ref) {
    return uploadManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UploadManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UploadManager>(value),
    );
  }
}

String _$uploadManagerHash() => r'9f636cc37381c17373522cee0ba671657960bfec';

/// API service depends on auth service

@ProviderFor(apiService)
const apiServiceProvider = ApiServiceProvider._();

/// API service depends on auth service

final class ApiServiceProvider
    extends $FunctionalProvider<ApiService, ApiService, ApiService>
    with $Provider<ApiService> {
  /// API service depends on auth service
  const ApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiServiceHash();

  @$internal
  @override
  $ProviderElement<ApiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ApiService create(Ref ref) {
    return apiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiService>(value),
    );
  }
}

String _$apiServiceHash() => r'a114c5e161b816881b395a10c90d043ef94c8de7';

/// Crosspost API client for Bluesky toggle settings

@ProviderFor(crosspostApiClient)
const crosspostApiClientProvider = CrosspostApiClientProvider._();

/// Crosspost API client for Bluesky toggle settings

final class CrosspostApiClientProvider
    extends
        $FunctionalProvider<
          CrosspostApiClient,
          CrosspostApiClient,
          CrosspostApiClient
        >
    with $Provider<CrosspostApiClient> {
  /// Crosspost API client for Bluesky toggle settings
  const CrosspostApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crosspostApiClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crosspostApiClientHash();

  @$internal
  @override
  $ProviderElement<CrosspostApiClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CrosspostApiClient create(Ref ref) {
    return crosspostApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrosspostApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrosspostApiClient>(value),
    );
  }
}

String _$crosspostApiClientHash() =>
    r'b1bd6e7666b565c069cd7eaf6c24108366887124';

/// Video event publisher depends on multiple services

@ProviderFor(videoEventPublisher)
const videoEventPublisherProvider = VideoEventPublisherProvider._();

/// Video event publisher depends on multiple services

final class VideoEventPublisherProvider
    extends
        $FunctionalProvider<
          VideoEventPublisher,
          VideoEventPublisher,
          VideoEventPublisher
        >
    with $Provider<VideoEventPublisher> {
  /// Video event publisher depends on multiple services
  const VideoEventPublisherProvider._()
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
    r'6b1327889373d9366f38c387a953b188eba9fbcd';

/// View event publisher for kind 22236 ephemeral analytics events
///
/// Publishes video view events to track watch time, traffic sources,
/// and enable creator analytics and recommendation systems.

@ProviderFor(viewEventPublisher)
const viewEventPublisherProvider = ViewEventPublisherProvider._();

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
  const ViewEventPublisherProvider._()
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

/// Subscribed list video cache for merging subscribed list videos into home feed
/// Depends on CuratedListService which is async, so watch the state provider

@ProviderFor(subscribedListVideoCache)
const subscribedListVideoCacheProvider = SubscribedListVideoCacheProvider._();

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
  const SubscribedListVideoCacheProvider._()
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
    r'5d1d88d9b9cd3b3feee51edd95eb8db9dfbf2371';

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

/// Video sharing service
///
/// When a [DmRepository] is available the service sends videos via NIP-17
/// encrypted DMs (NIP-17). Otherwise falls back to NIP-04 kind 4.

@ProviderFor(videoSharingService)
const videoSharingServiceProvider = VideoSharingServiceProvider._();

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
  const VideoSharingServiceProvider._()
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

/// Service that orchestrates the video-metadata-edit republish flow.

@ProviderFor(videoMetadataUpdateService)
const videoMetadataUpdateServiceProvider =
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
  const VideoMetadataUpdateServiceProvider._()
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

/// Account Deletion Service for NIP-62 Request to Vanish

@ProviderFor(accountDeletionService)
const accountDeletionServiceProvider = AccountDeletionServiceProvider._();

/// Account Deletion Service for NIP-62 Request to Vanish

final class AccountDeletionServiceProvider
    extends
        $FunctionalProvider<
          AccountDeletionService,
          AccountDeletionService,
          AccountDeletionService
        >
    with $Provider<AccountDeletionService> {
  /// Account Deletion Service for NIP-62 Request to Vanish
  const AccountDeletionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDeletionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDeletionServiceHash();

  @$internal
  @override
  $ProviderElement<AccountDeletionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountDeletionService create(Ref ref) {
    return accountDeletionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountDeletionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountDeletionService>(value),
    );
  }
}

String _$accountDeletionServiceHash() =>
    r'659c0ee712559ba34e462dc9b236c40c80651240';

/// Broken video tracker service for filtering non-functional videos

@ProviderFor(brokenVideoTracker)
const brokenVideoTrackerProvider = BrokenVideoTrackerProvider._();

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
  const BrokenVideoTrackerProvider._()
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

/// Audio playback service for sound playback during recording and preview
///
/// Used by SoundsScreen to preview sounds and by camera screen
/// for lip-sync recording. Handles audio loading, play/pause, and cleanup.
/// Uses keepAlive to persist across the session (not auto-disposed).

@ProviderFor(audioPlaybackService)
const audioPlaybackServiceProvider = AudioPlaybackServiceProvider._();

/// Audio playback service for sound playback during recording and preview
///
/// Used by SoundsScreen to preview sounds and by camera screen
/// for lip-sync recording. Handles audio loading, play/pause, and cleanup.
/// Uses keepAlive to persist across the session (not auto-disposed).

final class AudioPlaybackServiceProvider
    extends
        $FunctionalProvider<
          AudioPlaybackService,
          AudioPlaybackService,
          AudioPlaybackService
        >
    with $Provider<AudioPlaybackService> {
  /// Audio playback service for sound playback during recording and preview
  ///
  /// Used by SoundsScreen to preview sounds and by camera screen
  /// for lip-sync recording. Handles audio loading, play/pause, and cleanup.
  /// Uses keepAlive to persist across the session (not auto-disposed).
  const AudioPlaybackServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioPlaybackServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioPlaybackServiceHash();

  @$internal
  @override
  $ProviderElement<AudioPlaybackService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioPlaybackService create(Ref ref) {
    return audioPlaybackService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioPlaybackService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioPlaybackService>(value),
    );
  }
}

String _$audioPlaybackServiceHash() =>
    r'dd192ad5fbcd8f4d42de658e409ef09f3c887f04';

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

/// Provider for VideoLocalStorage instance (SQLite-backed)
///
/// Creates a DbVideoLocalStorage for caching video events locally.
/// Used by VideosRepository for cache-first lookups.
///
/// Uses:
/// - NostrEventsDao from databaseProvider (for SQLite storage)

@ProviderFor(videoLocalStorage)
const videoLocalStorageProvider = VideoLocalStorageProvider._();

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
  const VideoLocalStorageProvider._()
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
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - VideoLocalStorage for cache-first lookups and caching results
/// - ContentBlocklistRepository for filtering blocked/muted users
/// - ContentFilterService for filtering NSFW content based on user preferences
/// - FunnelcakeApiClient for trending/popular video sorting

@ProviderFor(videosRepository)
const videosRepositoryProvider = VideosRepositoryProvider._();

/// Provider for VideosRepository instance
///
/// Creates a VideosRepository for loading video feeds with pagination.
/// Works without authentication for public feeds.
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
  /// Uses:
  /// - NostrClient from nostrServiceProvider (for relay communication)
  /// - VideoLocalStorage for cache-first lookups and caching results
  /// - ContentBlocklistRepository for filtering blocked/muted users
  /// - ContentFilterService for filtering NSFW content based on user preferences
  /// - FunnelcakeApiClient for trending/popular video sorting
  const VideosRepositoryProvider._()
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

String _$videosRepositoryHash() => r'23565018788d961099e00b121cd79a285476e56e';

/// Provider for LikesRepository instance
///
/// Creates a LikesRepository when the user is authenticated.
/// Returns null when user is not authenticated.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalReactionsDao from databaseProvider (for local storage)

@ProviderFor(likesRepository)
const likesRepositoryProvider = LikesRepositoryProvider._();

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
  const LikesRepositoryProvider._()
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

String _$likesRepositoryHash() => r'96460364fea5b82e9717a420d542f8a2a865da48';

/// Provider for RepostsRepository instance
///
/// Creates a RepostsRepository for managing user reposts (Kind 16 generic
/// reposts).
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalRepostsDao from databaseProvider (for local storage)

@ProviderFor(repostsRepository)
const repostsRepositoryProvider = RepostsRepositoryProvider._();

/// Provider for RepostsRepository instance
///
/// Creates a RepostsRepository for managing user reposts (Kind 16 generic
/// reposts).
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalRepostsDao from databaseProvider (for local storage)

final class RepostsRepositoryProvider
    extends
        $FunctionalProvider<
          RepostsRepository,
          RepostsRepository,
          RepostsRepository
        >
    with $Provider<RepostsRepository> {
  /// Provider for RepostsRepository instance
  ///
  /// Creates a RepostsRepository for managing user reposts (Kind 16 generic
  /// reposts).
  ///
  /// Uses:
  /// - NostrClient from nostrServiceProvider (for relay communication)
  /// - PersonalRepostsDao from databaseProvider (for local storage)
  const RepostsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'repostsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$repostsRepositoryHash();

  @$internal
  @override
  $ProviderElement<RepostsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RepostsRepository create(Ref ref) {
    return repostsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RepostsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RepostsRepository>(value),
    );
  }
}

String _$repostsRepositoryHash() => r'057ff5e60002499eee0dffa809e1ddb72f7c817c';
