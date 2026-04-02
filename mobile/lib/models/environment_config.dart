// ABOUTME: Environment configuration model for poc/staging/test/production/local
// ABOUTME: Each environment maps to exactly one relay URL and API base URL

/// Host address from Android emulator to reach the host machine's localhost.
const localHost = '10.0.2.2';

/// Local Docker stack port mappings.
const localKeycastPort = 43000;
const localRelayPort = 47777;
const localApiPort = 43001;
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
