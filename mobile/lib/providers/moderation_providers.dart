// ABOUTME: Content-moderation Riverpod providers split from app_providers.dart
// ABOUTME: Policy engine, host/age/content filters, NIP-32 labels, blocklist + sync bridge

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/blocklist_content_filter.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'moderation_providers.g.dart';

@Riverpod(keepAlive: true)
ContentPolicyEngine contentPolicyEngine(Ref ref) {
  return ContentPolicyEngine.defaultRules();
}

/// Whether the UI may offer interactions that target [pubkey] —
/// follow, DM, reply, mention, share-to, tag.
///
/// When this returns `false` the affordance must be *absent*: no disabled
/// state, no tooltip, no copy. Revealing why would violate the disclosure
/// invariant (the app never tells a user someone blocked or muted them).
///
/// Under [FeatureFlag.contentPolicyV2] this consults
/// [ContentPolicyEngine.canTarget] (hidden when the target's published
/// kind 30000 d=block or kind 10000 names us). With the flag off it
/// preserves the pre-engine behavior: only an explicit block
/// (`hasBlockedUs`) hides the affordance.
@riverpod
bool canTargetUser(Ref ref, String pubkey) {
  // Re-evaluate when any block/mute state changes.
  ref.watch(blocklistVersionProvider);
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
  final flagService = ref.watch(featureFlagServiceProvider);
  if (flagService.isEnabled(FeatureFlag.contentPolicyV2)) {
    final engine = ref.watch(contentPolicyEngineProvider);
    return engine.canTarget(pubkey, blocklistRepository.currentState);
  }
  return !blocklistRepository.hasBlockedUs(pubkey);
}

/// Divine-hosted-only filter preference service.
final divineHostFilterServiceProvider = Provider<DivineHostFilterService>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = DivineHostFilterService(prefs);
  ref.onDispose(service.dispose);
  return service;
});

/// Rebuild trigger for consumers that need to react to Divine-host filter
/// preference changes.
final divineHostFilterVersionProvider = Provider<int>((ref) {
  final service = ref.watch(divineHostFilterServiceProvider);
  var version = 0;

  void listener() {
    version++;
    ref.invalidateSelf();
  }

  service.addListener(listener);
  ref.onDispose(() => service.removeListener(listener));
  return version;
});

/// Age verification service for content creation restrictions
/// keepAlive ensures the service persists and maintains in-memory verification state
/// even when widgets that watch it dispose and rebuild
@Riverpod(keepAlive: true)
AgeVerificationService ageVerificationService(Ref ref) {
  final service = AgeVerificationService();
  service.initialize(); // Initialize asynchronously
  return service;
}

/// Content filter service for per-category Show/Warn/Hide preferences.
/// keepAlive ensures preferences persist and are consistent across the app.
@Riverpod(keepAlive: true)
ContentFilterService contentFilterService(Ref ref) {
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);
  final service = ContentFilterService(
    ageVerificationService: ageVerificationService,
  );
  service.initialize(); // Initialize asynchronously
  ref.onDispose(service.dispose);
  return service;
}

/// Tracks content filter preference changes. Feed providers watch this
/// to rebuild when the user changes a Show/Warn/Hide setting.
@Riverpod(keepAlive: true)
int contentFilterVersion(Ref ref) {
  final service = ref.watch(contentFilterServiceProvider);
  final aspectRatioPreference = ref.watch(
    feedAspectRatioPreferenceServiceProvider,
  );
  var version = 0;
  void listener() {
    version++;
    ref.invalidateSelf();
  }

  service.addListener(listener);
  aspectRatioPreference.addListener(listener);
  ref.onDispose(() {
    service.removeListener(listener);
    aspectRatioPreference.removeListener(listener);
  });
  return version;
}

/// Account label service for self-labeling content (NIP-32 Kind 1985).
@Riverpod(keepAlive: true)
AccountLabelService accountLabelService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final nostrClient = ref.watch(nostrServiceProvider);
  final service = AccountLabelService(
    authService: authService,
    nostrClient: nostrClient,
  );
  service.initialize();
  return service;
}

/// Moderation label service for subscribing to Kind 1985 labeler events.
@Riverpod(keepAlive: true)
ModerationLabelService moderationLabelService(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final followRepository = ref.watch(followRepositoryProvider);
  final service = ModerationLabelService(
    nostrClient: nostrClient,
    authService: authService,
    sharedPreferences: prefs,
  );
  unawaited(
    service.initialize().then((_) {
      return service.syncFollowedLabelers(followRepository.followingPubkeys);
    }),
  );
  final followingSubscription = followRepository.followingStream.listen((
    pubkeys,
  ) {
    unawaited(service.syncFollowedLabelers(pubkeys));
  });
  ref.onDispose(() {
    followingSubscription.cancel();
    service.dispose();
  });
  return service;
}

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
@Riverpod(keepAlive: true)
ContentBlocklistRepository contentBlocklistRepository(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ContentBlocklistRepository(
    prefs: prefs,
    onChanged: () {
      if (!ref.mounted) return;
      ref.read(blocklistVersionProvider.notifier).increment();
    },
  );
}

/// Version counter to trigger rebuilds when blocklist changes.
/// Widgets watching this will rebuild when block/unblock actions occur.
@riverpod
class BlocklistVersion extends _$BlocklistVersion {
  @override
  int build() => 0;

  void increment() => state++;
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
@Riverpod(keepAlive: true)
void blocklistSyncBridge(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

  Future<void> startSync(NostrSessionReadiness readiness) async {
    final pubkey = readiness.pubkey;
    final client = readiness.client;
    if (!readiness.isReadyForActiveClient || pubkey == null || client == null) {
      return;
    }

    if (authService.currentIdentity?.pubkey != pubkey) {
      return;
    }

    try {
      await Future.wait([
        blocklistRepository.syncMuteListsInBackground(client, pubkey),
        blocklistRepository.syncBlockListsInBackground(
          client,
          authService,
          pubkey,
        ),
      ]);
      Log.info(
        '[BRIDGE] Block/mute list sync started',
        name: 'BlocklistSyncBridge',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.warning(
        '[BRIDGE] Block/mute list sync failed (non-critical): $e',
        name: 'BlocklistSyncBridge',
        category: LogCategory.system,
      );
    }
  }

  unawaited(startSync(ref.read(nostrSessionProvider)));

  ref.listen<NostrSessionReadiness>(nostrSessionProvider, (_, next) {
    unawaited(startSync(next));
  });
}

/// Builds the blocked-author video filter, selecting the content-policy engine
/// when [FeatureFlag.contentPolicyV2] is enabled and falling back to the
/// blocklist filter otherwise.
BlockedVideoFilter createBlockedAuthorFilter(Ref ref) {
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
  final flagService = ref.watch(featureFlagServiceProvider);
  if (flagService.isEnabled(FeatureFlag.contentPolicyV2)) {
    final engine = ref.watch(contentPolicyEngineProvider);
    return createPolicyEngineFilter(
      engine,
      () => blocklistRepository.currentState,
    );
  }

  return createBlocklistFilter(blocklistRepository);
}
