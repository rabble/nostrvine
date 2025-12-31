// ABOUTME: Factory for creating NostrClient instances
// ABOUTME: Handles platform-appropriate client creation with proper configuration

import 'package:db_client/db_client.dart';
import 'package:nostr_client/nostr_client.dart';
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
  }) {
    UnifiedLogger.info(
      'Creating NostrClient via factory',
      name: 'NostrServiceFactory',
    );

    // Create signer with the current key container
    final signer = AuthServiceSigner(keyContainer);

    // Create NostrClient config
    final config = NostrClientConfig(
      signer: signer,
      publicKey: keyContainer?.publicKeyHex ?? '',
    );

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
