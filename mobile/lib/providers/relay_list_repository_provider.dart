// ABOUTME: Riverpod wiring for NIP-65 relay-list publishing and dirty retry.
// ABOUTME: Activated by AppShellSideEffects with the other relay bridges.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_discovery_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/relay_list_repository.dart';
import 'package:unified_logger/unified_logger.dart';

final relayListRepositoryProvider = Provider<RelayListRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return RelayListRepository(
    nostrClient: ref.watch(nostrServiceProvider),
    environment: ref.watch(currentEnvironmentProvider),
    relayDiscoveryService: ref.watch(relayDiscoveryServiceProvider),
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    discoveredRelays: () => authService.userRelays,
  );
});

final relayListDirtyPublishBridgeProvider = Provider<void>((ref) {
  Future<void> retryIfDirty(NostrSessionReadiness readiness) async {
    if (!readiness.isReadyForActiveClient) return;
    final pubkey = readiness.pubkey;
    if (pubkey == null || pubkey.isEmpty) return;

    final repository = ref.read(relayListRepositoryProvider);
    if (!repository.isDirty(pubkey)) return;

    final result = await repository.retryDirtyPublish();
    if (result.localOnly) {
      Log.warning(
        'kind:10002 dirty relay-list retry did not reach an indexer',
        name: 'RelayListDirtyPublishBridge',
        category: LogCategory.relay,
      );
    }
  }

  unawaited(retryIfDirty(ref.read(nostrSessionProvider)));
  ref.listen<NostrSessionReadiness>(
    nostrSessionProvider,
    (_, next) => unawaited(retryIfDirty(next)),
  );
});
