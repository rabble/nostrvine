// ABOUTME: Factory for creating NostrClient instances
// ABOUTME: Handles platform-appropriate client creation with proper configuration

import 'package:db_client/db_client.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Factory class for creating NostrClient instances
class NostrServiceFactory {
  /// Create a NostrClient for the current platform.
  ///
  /// [signer] is the single source of truth for the current user's public
  /// key and all signing operations. Pass `authService.currentIdentity`.
  ///
  /// Takes [environmentConfig] to determine the relay URL to use.
  /// If not provided, falls back to [AppConstants.defaultRelayUrl].
  ///
  /// Takes [dbClient] for local event caching with optimistic updates.
  ///
  /// Note: User relays (NIP-65) should be added separately via
  /// [NostrClient.addRelays] and awaited BEFORE calling [initialize]
  /// to avoid race conditions.
  static NostrClient create({
    required NostrSigner signer,
    RelayStatisticsService? statisticsService,
    EnvironmentConfig? environmentConfig,
    AppDbClient? dbClient,
  }) {
    final divineRelayUrl =
        environmentConfig?.relayUrl ?? AppConstants.defaultRelayUrl;

    UnifiedLogger.info(
      'Creating NostrClient via factory with Divine relay: $divineRelayUrl',
      name: 'NostrServiceFactory',
    );

    final config = NostrClientConfig(signer: signer);

    // Create relay manager config with persistent storage
    // The Divine relay is always the default relay (cannot be removed)
    final relayManagerConfig = RelayManagerConfig(
      defaultRelayUrl: divineRelayUrl,
      storage: SharedPreferencesRelayStorage(),
    );

    // Create the NostrClient
    final client = NostrClient(
      config: config,
      relayManagerConfig: relayManagerConfig,
      dbClient: dbClient,
    );

    return client;
  }

  /// Initialize the created client
  static Future<void> initialize(NostrClient client) async {
    await client.initialize();
  }
}
