// ABOUTME: Environment configuration model for poc/staging/test/production/local
// ABOUTME: Each environment maps to exactly one relay URL and API base URL

/// Host address from Android emulator to reach the host machine's localhost.
///
/// Mirrored in the native transport-security configs that allow cleartext
/// to loopback hosts:
///   - mobile/android/app/src/main/res/xml/network_security_config.xml
///   - mobile/ios/Runner/Info.plist (NSAllowsLocalNetworking)
///   - mobile/macos/Runner/Info.plist (NSAllowsLocalNetworking)
/// Keep this constant in sync with the Android <domain-config> list.
const localHost = '10.0.2.2';

/// Local Docker stack port mappings.
const localKeycastPort = 43000;
const localRelayPort = 47777;

/// REST API port — shares the funnelcake-proxy with the relay (nginx routes
/// `/api/*` to funnelcake-api, everything else to the relay WebSocket).
const int localApiPort = localRelayPort;
const localBlossomPort = 43003;
const localInvitePort = 43004;
const productionApiBaseUrl = 'https://api.divine.video';

/// Build-time default environment
/// Set via: --dart-define=DEFAULT_ENV=STAGING
const String _defaultEnvString = String.fromEnvironment(
  'DEFAULT_ENV',
  defaultValue: 'PRODUCTION',
);

/// Parse build-time default to AppEnvironment
AppEnvironment get buildTimeDefaultEnvironment {
  switch (_defaultEnvString.toUpperCase()) {
    case 'POC':
      return AppEnvironment.poc;
    case 'STAGING':
      return AppEnvironment.staging;
    case 'TEST':
      return AppEnvironment.test;
    case 'LOCAL':
      return AppEnvironment.local;
    case 'PRODUCTION':
    default:
      return AppEnvironment.production;
  }
}

/// Available app environments
enum AppEnvironment { poc, staging, test, production, local }

/// Configuration for the current app environment
class EnvironmentConfig {
  const EnvironmentConfig({required this.environment});

  final AppEnvironment environment;

  /// Default production configuration
  static const production = EnvironmentConfig(
    environment: AppEnvironment.production,
  );

  /// Get relay URL for current environment
  String get relayUrl {
    switch (environment) {
      case AppEnvironment.poc:
        return 'wss://relay.poc.dvines.org';
      case AppEnvironment.staging:
        return 'wss://relay.staging.dvines.org';
      case AppEnvironment.test:
        return 'wss://relay.test.dvines.org';
      case AppEnvironment.local:
        return 'ws://$localHost:$localRelayPort';
      case AppEnvironment.production:
        return 'wss://relay.divine.video';
    }
  }

  /// Get REST API base URL (FunnelCake REST API)
  ///
  /// For local environment, the API runs on a separate port from the relay.
  /// Production uses the Fastly-backed API host while other environments
  /// derive from the relay URL to stay in sync.
  String get apiBaseUrl {
    if (environment == AppEnvironment.local) {
      return 'http://$localHost:$localApiPort';
    }
    if (environment == AppEnvironment.production) {
      return productionApiBaseUrl;
    }
    final url = relayUrl;
    if (url.startsWith('wss://')) {
      return url.replaceFirst('wss://', 'https://');
    } else if (url.startsWith('ws://')) {
      return url.replaceFirst('ws://', 'http://');
    }
    return url;
  }

  /// Get blossom media server URL
  String get blossomUrl {
    if (environment == AppEnvironment.local) {
      return 'http://$localHost:$localBlossomPort';
    }
    return 'https://media.divine.video';
  }

  /// Indexer relay URLs for the current environment.
  ///
  /// In LOCAL mode, queries go to the local funnelcake relay to avoid
  /// wasting time querying external indexers for test-created users.
  List<String> get indexerRelays {
    if (environment == AppEnvironment.local) {
      return ['ws://$localHost:$localRelayPort'];
    }
    return const [
      'wss://purplepag.es',
      'wss://user.kindpag.es',
      'wss://relay.nos.social',
    ];
  }

  /// Get relay manager API URL (divine-relay-manager worker)
  String get relayManagerApiUrl {
    switch (environment) {
      case AppEnvironment.local:
        return 'http://$localHost:8787';
      case AppEnvironment.poc:
      case AppEnvironment.test:
      case AppEnvironment.staging:
        return 'https://api-relay-staging.divine.video';
      case AppEnvironment.production:
        return 'https://api-relay-prod.divine.video';
    }
  }

  /// Whether this is production environment
  bool get isProduction => environment == AppEnvironment.production;

  /// Human readable display name
  String get displayName {
    switch (environment) {
      case AppEnvironment.poc:
        return 'POC';
      case AppEnvironment.staging:
        return 'Staging';
      case AppEnvironment.test:
        return 'Test';
      case AppEnvironment.local:
        return 'Local';
      case AppEnvironment.production:
        return 'Production';
    }
  }

  /// Public key of the divine-push-service for this environment.
  /// Used for NIP-44 encryption of FCM token registration events.
  /// Obtain from GET /health on the push service.
  String get pushServicePubkey {
    switch (environment) {
      case AppEnvironment.poc:
        return '2fc7d43fc02ae951a226108d3a31330bd26f37c1ef88eaa91948251de98b049d';
      case AppEnvironment.staging:
        return '5414dcebf15d0d8b36fb80c6295ae4222113b61807e777870cbd1fd422a35809';
      case AppEnvironment.test:
        return '5414dcebf15d0d8b36fb80c6295ae4222113b61807e777870cbd1fd422a35809';
      case AppEnvironment.local:
        return '5414dcebf15d0d8b36fb80c6295ae4222113b61807e777870cbd1fd422a35809';
      case AppEnvironment.production:
        return '2f871aaa4a519da94aeb5ebffe7587549158855c4460e7a5a1b91d36d2fb5b04';
    }
  }

  /// Color for environment indicator (as int for const constructor)
  int get indicatorColorValue {
    switch (environment) {
      case AppEnvironment.poc:
        return 0xFFFF7640; // accentOrange
      case AppEnvironment.staging:
        return 0xFFFFF140; // accentYellow
      case AppEnvironment.test:
        return 0xFF34BBF1; // accentBlue
      case AppEnvironment.local:
        return 0xFFE040FB; // accentPurple
      case AppEnvironment.production:
        return 0xFF27C58B; // primaryGreen
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvironmentConfig && environment == other.environment;

  @override
  int get hashCode => environment.hashCode;
}
