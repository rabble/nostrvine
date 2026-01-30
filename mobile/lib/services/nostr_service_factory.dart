// ABOUTME: Factory for creating NostrClient instances
// ABOUTME: Handles platform-appropriate client creation with proper configuration

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/auth_service_signer.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Factory class for creating NostrClient instances
class NostrServiceFactory {
  /// Create a NostrClient for the current platform
  ///
  /// Takes [keyContainer] directly since the nostrServiceProvider rebuilds
  /// when auth state changes, ensuring the key container is always current.
  ///
  /// Takes [environmentConfig] to determine the relay URL to use.
  /// If not provided, falls back to [AppConstants.defaultRelayUrl].
  ///
  /// Takes [dbClient] for local event caching with optimistic updates.
  ///
  /// Takes [userRelayUrls] for user-discovered relays (NIP-65).
  /// These will be added in addition to the diVine relay.
  static NostrClient create({
    SecureKeyContainer? keyContainer,
    RelayStatisticsService? statisticsService,
    EnvironmentConfig? environmentConfig,
    AppDbClient? dbClient,
    List<String>? userRelayUrls,

    /// Optional remote RPC signer (e.g. `KeycastRpc`). If provided, this
    /// signer will be used instead of the local `AuthServiceSigner`.
    NostrSigner? rpcSigner,
  }) {
    final divineRelayUrl =
        environmentConfig?.relayUrl ?? AppConstants.defaultRelayUrl;

    UnifiedLogger.info(
      'Creating NostrClient via factory with diVine relay: $divineRelayUrl',
      name: 'NostrServiceFactory',
    );

    if (userRelayUrls != null && userRelayUrls.isNotEmpty) {
      UnifiedLogger.info(
        'Will add ${userRelayUrls.length} user relays (NIP-65)',
        name: 'NostrServiceFactory',
      );
    } else {
      UnifiedLogger.info(
        'No user relays discovered - using diVine relay only',
        name: 'NostrServiceFactory',
      );
    }

    // Prefer RPC signer when available (KeycastRpc implements NostrSigner),
    // otherwise fall back to local signer that uses the secure key container.
    // The signer is the single source of truth for the public key.
    final signer = rpcSigner ?? AuthServiceSigner(keyContainer);

    // Create NostrClient config - signer is the source of truth for publicKey
    final config = NostrClientConfig(signer: signer);

    // Create relay manager config with persistent storage
    // The diVine relay is always the default relay (cannot be removed)
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

    // Add user relays if available
    // These will be added asynchronously during initialization
    if (userRelayUrls != null && userRelayUrls.isNotEmpty) {
      unawaited(_addUserRelays(client, userRelayUrls));
    }

    return client;
  }

  /// Initialize the created client
  static Future<void> initialize(NostrClient client) async {
    await client.initialize();
  }

  /// Add user relays asynchronously (fire-and-forget)
  static Future<void> _addUserRelays(
    NostrClient client,
    List<String> userRelayUrls,
  ) async {
    for (final relayUrl in userRelayUrls) {
      try {
        final added = await client.addRelay(relayUrl);
        if (added) {
          UnifiedLogger.info(
            '✅ Added user relay: $relayUrl',
            name: 'NostrServiceFactory',
          );
        } else {
          UnifiedLogger.warning(
            '⚠️ Failed to add user relay: $relayUrl',
            name: 'NostrServiceFactory',
          );
        }
      } catch (e) {
        UnifiedLogger.error(
          '❌ Error adding user relay $relayUrl: $e',
          name: 'NostrServiceFactory',
        );
      }
    }

    UnifiedLogger.info(
      '📡 Relay setup complete - connected to ${1 + userRelayUrls.length} relays total',
      name: 'NostrServiceFactory',
    );
  }
}
