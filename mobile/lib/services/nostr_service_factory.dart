// ABOUTME: Factory for creating NostrClient instances
// ABOUTME: Handles platform-appropriate client creation with proper configuration

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_gateway/nostr_gateway.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/auth_service_signer.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Factory class for creating NostrClient instances
class NostrServiceFactory {
  /// Create a NostrClient for the current platform
  ///
  /// Uses [keyContainerGetter] to lazily get the key container at signing time.
  /// This allows the client to be created before auth is ready, and signing
  /// will work automatically once the user is authenticated.
  static NostrClient create(
    KeyContainerGetter keyContainerGetter, {
    RelayStatisticsService? statisticsService,
    RelayGatewaySettings? gatewaySettings,
  }) {
    UnifiedLogger.info(
      'Creating NostrClient via factory with lazy auth',
      name: 'NostrServiceFactory',
    );

    // Create signer that gets key container at signing time
    final signer = AuthServiceSigner(keyContainerGetter);

    // Create NostrClient config - publicKey may be empty initially
    final config = NostrClientConfig(
      signer: signer,
      publicKey: keyContainerGetter()?.publicKeyHex ?? '',
    );

    // Create relay manager config with persistent storage
    final relayManagerConfig = RelayManagerConfig(
      defaultRelayUrl: AppConstants.defaultRelayUrl,
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
    );
  }

  /// Initialize the created client
  static Future<void> initialize(NostrClient client) async {
    await client.initialize();
  }
}
