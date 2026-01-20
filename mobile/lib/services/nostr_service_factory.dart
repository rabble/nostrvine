// ABOUTME: Factory for creating NostrClient instances
// ABOUTME: Handles platform-appropriate client creation with proper configuration

import 'package:db_client/db_client.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_gateway/nostr_gateway.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/auth_service_signer.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
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
  static NostrClient create({
    SecureKeyContainer? keyContainer,
    RelayStatisticsService? statisticsService,
    RelayGatewaySettings? gatewaySettings,
    EnvironmentConfig? environmentConfig,
    AppDbClient? dbClient,

    /// Optional remote RPC signer (e.g. `KeycastRpc`). If provided, this
    /// signer will be used instead of the local `AuthServiceSigner`.
    NostrSigner? rpcSigner,
  }) {
    UnifiedLogger.info(
      'Creating NostrClient via factory',
      name: 'NostrServiceFactory',
    );

    // Prefer RPC signer when available (KeycastRpc implements NostrSigner),
    // otherwise fall back to local signer that uses the secure key container.
    // The signer is the single source of truth for the public key.
    final signer = rpcSigner ?? AuthServiceSigner(keyContainer);

    // Create NostrClient config - signer is the source of truth for publicKey
    final config = NostrClientConfig(signer: signer);

    // Create relay manager config with persistent storage
    // Use relay URL from environment config if provided, otherwise fall back to default
    final relayUrl =
        environmentConfig?.relayUrl ?? AppConstants.defaultRelayUrl;
    final relayManagerConfig = RelayManagerConfig(
      defaultRelayUrl: relayUrl,
      storage: SharedPreferencesRelayStorage(),
    );

    // Create gateway client if settings enable it
    GatewayClient? gatewayClient;
    if (gatewaySettings != null && gatewaySettings.isEnabled) {
      gatewayClient = GatewayClient(gatewayUrl: gatewaySettings.gatewayUrl);
      UnifiedLogger.info(
        'Gateway enabled: ${gatewaySettings.gatewayUrl}',
        name: 'NostrServiceFactory',
      );
    }

    // Create the NostrClient
    return NostrClient(
      config: config,
      relayManagerConfig: relayManagerConfig,
      gatewayClient: gatewayClient,
      dbClient: dbClient,
    );
  }

  /// Initialize the created client
  static Future<void> initialize(NostrClient client) async {
    await client.initialize();
  }
}
