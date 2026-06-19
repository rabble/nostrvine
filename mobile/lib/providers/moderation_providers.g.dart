// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moderation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contentPolicyEngine)
final contentPolicyEngineProvider = ContentPolicyEngineProvider._();

final class ContentPolicyEngineProvider
    extends
        $FunctionalProvider<
          ContentPolicyEngine,
          ContentPolicyEngine,
          ContentPolicyEngine
        >
    with $Provider<ContentPolicyEngine> {
  ContentPolicyEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentPolicyEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentPolicyEngineHash();

  @$internal
  @override
  $ProviderElement<ContentPolicyEngine> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ContentPolicyEngine create(Ref ref) {
    return contentPolicyEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContentPolicyEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContentPolicyEngine>(value),
    );
  }
}

String _$contentPolicyEngineHash() =>
    r'3e6e0f8415da251057c220f5873bd5359c6ce9f1';

/// Whether the UI may offer interactions that target [pubkey] —
/// follow, DM, reply, mention, share-to, tag.
///
/// When this returns `false` the affordance must be *absent*: no disabled
/// state, no tooltip, no copy. Revealing why would violate the disclosure
/// invariant (the app never tells a user someone blocked or muted them).
///
/// Consults [ContentPolicyEngine.canTarget]: the affordance is hidden when
/// the target's published kind 30000 d=block or kind 10000 mute list names
/// the current user.

@ProviderFor(canTargetUser)
final canTargetUserProvider = CanTargetUserFamily._();

/// Whether the UI may offer interactions that target [pubkey] —
/// follow, DM, reply, mention, share-to, tag.
///
/// When this returns `false` the affordance must be *absent*: no disabled
/// state, no tooltip, no copy. Revealing why would violate the disclosure
/// invariant (the app never tells a user someone blocked or muted them).
///
/// Consults [ContentPolicyEngine.canTarget]: the affordance is hidden when
/// the target's published kind 30000 d=block or kind 10000 mute list names
/// the current user.

final class CanTargetUserProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the UI may offer interactions that target [pubkey] —
  /// follow, DM, reply, mention, share-to, tag.
  ///
  /// When this returns `false` the affordance must be *absent*: no disabled
  /// state, no tooltip, no copy. Revealing why would violate the disclosure
  /// invariant (the app never tells a user someone blocked or muted them).
  ///
  /// Consults [ContentPolicyEngine.canTarget]: the affordance is hidden when
  /// the target's published kind 30000 d=block or kind 10000 mute list names
  /// the current user.
  CanTargetUserProvider._({
    required CanTargetUserFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'canTargetUserProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$canTargetUserHash();

  @override
  String toString() {
    return r'canTargetUserProvider'
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
    return canTargetUser(ref, argument);
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
    return other is CanTargetUserProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$canTargetUserHash() => r'96f7718c9d61620ad1b239a7a553df858165007e';

/// Whether the UI may offer interactions that target [pubkey] —
/// follow, DM, reply, mention, share-to, tag.
///
/// When this returns `false` the affordance must be *absent*: no disabled
/// state, no tooltip, no copy. Revealing why would violate the disclosure
/// invariant (the app never tells a user someone blocked or muted them).
///
/// Consults [ContentPolicyEngine.canTarget]: the affordance is hidden when
/// the target's published kind 30000 d=block or kind 10000 mute list names
/// the current user.

final class CanTargetUserFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  CanTargetUserFamily._()
    : super(
        retry: null,
        name: r'canTargetUserProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether the UI may offer interactions that target [pubkey] —
  /// follow, DM, reply, mention, share-to, tag.
  ///
  /// When this returns `false` the affordance must be *absent*: no disabled
  /// state, no tooltip, no copy. Revealing why would violate the disclosure
  /// invariant (the app never tells a user someone blocked or muted them).
  ///
  /// Consults [ContentPolicyEngine.canTarget]: the affordance is hidden when
  /// the target's published kind 30000 d=block or kind 10000 mute list names
  /// the current user.

  CanTargetUserProvider call(String pubkey) =>
      CanTargetUserProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'canTargetUserProvider';
}

/// Age verification service for content creation restrictions
/// keepAlive ensures the service persists and maintains in-memory verification state
/// even when widgets that watch it dispose and rebuild

@ProviderFor(ageVerificationService)
final ageVerificationServiceProvider = AgeVerificationServiceProvider._();

/// Age verification service for content creation restrictions
/// keepAlive ensures the service persists and maintains in-memory verification state
/// even when widgets that watch it dispose and rebuild

final class AgeVerificationServiceProvider
    extends
        $FunctionalProvider<
          AgeVerificationService,
          AgeVerificationService,
          AgeVerificationService
        >
    with $Provider<AgeVerificationService> {
  /// Age verification service for content creation restrictions
  /// keepAlive ensures the service persists and maintains in-memory verification state
  /// even when widgets that watch it dispose and rebuild
  AgeVerificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ageVerificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ageVerificationServiceHash();

  @$internal
  @override
  $ProviderElement<AgeVerificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AgeVerificationService create(Ref ref) {
    return ageVerificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgeVerificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgeVerificationService>(value),
    );
  }
}

String _$ageVerificationServiceHash() =>
    r'e866f0341e541ba27ba2b4e4278ed4b35edb8d8b';

/// Content filter service for per-category Show/Warn/Hide preferences.
/// keepAlive ensures preferences persist and are consistent across the app.

@ProviderFor(contentFilterService)
final contentFilterServiceProvider = ContentFilterServiceProvider._();

/// Content filter service for per-category Show/Warn/Hide preferences.
/// keepAlive ensures preferences persist and are consistent across the app.

final class ContentFilterServiceProvider
    extends
        $FunctionalProvider<
          ContentFilterService,
          ContentFilterService,
          ContentFilterService
        >
    with $Provider<ContentFilterService> {
  /// Content filter service for per-category Show/Warn/Hide preferences.
  /// keepAlive ensures preferences persist and are consistent across the app.
  ContentFilterServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentFilterServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentFilterServiceHash();

  @$internal
  @override
  $ProviderElement<ContentFilterService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ContentFilterService create(Ref ref) {
    return contentFilterService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContentFilterService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContentFilterService>(value),
    );
  }
}

String _$contentFilterServiceHash() =>
    r'72bd9f0073806dd7fe95434fb889c3cb5f5ba750';

/// Tracks content filter preference changes. Feed providers watch this
/// to rebuild when the user changes a Show/Warn/Hide setting.

@ProviderFor(contentFilterVersion)
final contentFilterVersionProvider = ContentFilterVersionProvider._();

/// Tracks content filter preference changes. Feed providers watch this
/// to rebuild when the user changes a Show/Warn/Hide setting.

final class ContentFilterVersionProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Tracks content filter preference changes. Feed providers watch this
  /// to rebuild when the user changes a Show/Warn/Hide setting.
  ContentFilterVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentFilterVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentFilterVersionHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return contentFilterVersion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$contentFilterVersionHash() =>
    r'56673804308df57936c83187968f318735b4869e';

/// Account label service for self-labeling content (NIP-32 Kind 1985).

@ProviderFor(accountLabelService)
final accountLabelServiceProvider = AccountLabelServiceProvider._();

/// Account label service for self-labeling content (NIP-32 Kind 1985).

final class AccountLabelServiceProvider
    extends
        $FunctionalProvider<
          AccountLabelService,
          AccountLabelService,
          AccountLabelService
        >
    with $Provider<AccountLabelService> {
  /// Account label service for self-labeling content (NIP-32 Kind 1985).
  AccountLabelServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountLabelServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountLabelServiceHash();

  @$internal
  @override
  $ProviderElement<AccountLabelService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountLabelService create(Ref ref) {
    return accountLabelService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountLabelService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountLabelService>(value),
    );
  }
}

String _$accountLabelServiceHash() =>
    r'c72d91b64d2c4522a482868be6bd053eba21a24b';

/// Moderation label service for subscribing to Kind 1985 labeler events.

@ProviderFor(moderationLabelService)
final moderationLabelServiceProvider = ModerationLabelServiceProvider._();

/// Moderation label service for subscribing to Kind 1985 labeler events.

final class ModerationLabelServiceProvider
    extends
        $FunctionalProvider<
          ModerationLabelService,
          ModerationLabelService,
          ModerationLabelService
        >
    with $Provider<ModerationLabelService> {
  /// Moderation label service for subscribing to Kind 1985 labeler events.
  ModerationLabelServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moderationLabelServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moderationLabelServiceHash();

  @$internal
  @override
  $ProviderElement<ModerationLabelService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ModerationLabelService create(Ref ref) {
    return moderationLabelService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModerationLabelService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModerationLabelService>(value),
    );
  }
}

String _$moderationLabelServiceHash() =>
    r'45b724bac4937ca6647a775d5dc7e4d87ad27c23';

/// Content blocklist service for filtering unwanted content from feeds
///
/// Injects SharedPreferences for local block persistence across restarts.
/// Nostr publishing (kind 30000) is initialized via [syncBlockListsInBackground]
/// during app startup in main.dart.
///
/// keepAlive ensures the relay subscription created by
/// [syncBlockListsInBackground] survives widget rebuilds. Without it the
/// provider auto-disposes, the subscription is lost, and blocks restored
/// from the relay are never delivered to new instances.

@ProviderFor(contentBlocklistRepository)
final contentBlocklistRepositoryProvider =
    ContentBlocklistRepositoryProvider._();

/// Content blocklist service for filtering unwanted content from feeds
///
/// Injects SharedPreferences for local block persistence across restarts.
/// Nostr publishing (kind 30000) is initialized via [syncBlockListsInBackground]
/// during app startup in main.dart.
///
/// keepAlive ensures the relay subscription created by
/// [syncBlockListsInBackground] survives widget rebuilds. Without it the
/// provider auto-disposes, the subscription is lost, and blocks restored
/// from the relay are never delivered to new instances.

final class ContentBlocklistRepositoryProvider
    extends
        $FunctionalProvider<
          ContentBlocklistRepository,
          ContentBlocklistRepository,
          ContentBlocklistRepository
        >
    with $Provider<ContentBlocklistRepository> {
  /// Content blocklist service for filtering unwanted content from feeds
  ///
  /// Injects SharedPreferences for local block persistence across restarts.
  /// Nostr publishing (kind 30000) is initialized via [syncBlockListsInBackground]
  /// during app startup in main.dart.
  ///
  /// keepAlive ensures the relay subscription created by
  /// [syncBlockListsInBackground] survives widget rebuilds. Without it the
  /// provider auto-disposes, the subscription is lost, and blocks restored
  /// from the relay are never delivered to new instances.
  ContentBlocklistRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentBlocklistRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentBlocklistRepositoryHash();

  @$internal
  @override
  $ProviderElement<ContentBlocklistRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ContentBlocklistRepository create(Ref ref) {
    return contentBlocklistRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContentBlocklistRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContentBlocklistRepository>(value),
    );
  }
}

String _$contentBlocklistRepositoryHash() =>
    r'018895442a5345b97d9d646ce1f4b39a065732e0';

/// Version counter to trigger rebuilds when blocklist changes.
/// Widgets watching this will rebuild when block/unblock actions occur.

@ProviderFor(BlocklistVersion)
final blocklistVersionProvider = BlocklistVersionProvider._();

/// Version counter to trigger rebuilds when blocklist changes.
/// Widgets watching this will rebuild when block/unblock actions occur.
final class BlocklistVersionProvider
    extends $NotifierProvider<BlocklistVersion, int> {
  /// Version counter to trigger rebuilds when blocklist changes.
  /// Widgets watching this will rebuild when block/unblock actions occur.
  BlocklistVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blocklistVersionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blocklistVersionHash();

  @$internal
  @override
  BlocklistVersion create() => BlocklistVersion();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$blocklistVersionHash() => r'ae0ea100b12ecea021ad9beded8cfe790665a532';

/// Version counter to trigger rebuilds when blocklist changes.
/// Widgets watching this will rebuild when block/unblock actions occur.

abstract class _$BlocklistVersion extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Bridge that starts blocklist sync when the Nostr session becomes ready.
///
/// Watch this at app shell level. It listens to [nostrSessionProvider] and
/// triggers [syncMuteListsInBackground] + [syncBlockListsInBackground]
/// the first time the signer-backed Nostr client is initialized. This covers:
/// - Already-authenticated startup (iOS keychain persists across reinstalls)
/// - Post-login authentication (Android wipes credentials on uninstall)
///
/// Both sync methods have internal guards (`_mutualMuteSyncStarted`,
/// `_blockListSyncStarted`) so duplicate calls are no-ops.

@ProviderFor(blocklistSyncBridge)
final blocklistSyncBridgeProvider = BlocklistSyncBridgeProvider._();

/// Bridge that starts blocklist sync when the Nostr session becomes ready.
///
/// Watch this at app shell level. It listens to [nostrSessionProvider] and
/// triggers [syncMuteListsInBackground] + [syncBlockListsInBackground]
/// the first time the signer-backed Nostr client is initialized. This covers:
/// - Already-authenticated startup (iOS keychain persists across reinstalls)
/// - Post-login authentication (Android wipes credentials on uninstall)
///
/// Both sync methods have internal guards (`_mutualMuteSyncStarted`,
/// `_blockListSyncStarted`) so duplicate calls are no-ops.

final class BlocklistSyncBridgeProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Bridge that starts blocklist sync when the Nostr session becomes ready.
  ///
  /// Watch this at app shell level. It listens to [nostrSessionProvider] and
  /// triggers [syncMuteListsInBackground] + [syncBlockListsInBackground]
  /// the first time the signer-backed Nostr client is initialized. This covers:
  /// - Already-authenticated startup (iOS keychain persists across reinstalls)
  /// - Post-login authentication (Android wipes credentials on uninstall)
  ///
  /// Both sync methods have internal guards (`_mutualMuteSyncStarted`,
  /// `_blockListSyncStarted`) so duplicate calls are no-ops.
  BlocklistSyncBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blocklistSyncBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blocklistSyncBridgeHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return blocklistSyncBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$blocklistSyncBridgeHash() =>
    r'0ffe1bb65877c094a330ec773089bb738247fe98';
