// ABOUTME: Environment configuration model for poc/staging/test/production
// ABOUTME: Each environment maps to exactly one relay URL and API base URL

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
    case 'PRODUCTION':
    default:
      return AppEnvironment.production;
  }
}

/// Available app environments
enum AppEnvironment { poc, staging, test, production }

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
      case AppEnvironment.production:
        return 'wss://relay.divine.video';
    }
  }

  /// Get REST API base URL
  String get apiBaseUrl {
    switch (environment) {
      case AppEnvironment.poc:
        return 'https://api.poc.dvines.org';
      case AppEnvironment.staging:
        return 'https://api.staging.dvines.org';
      case AppEnvironment.test:
        return 'https://api.test.dvines.org';
      case AppEnvironment.production:
        return 'https://api.divine.video';
    }
  }

  /// Get blossom media server URL (same for all environments currently)
  String get blossomUrl => 'https://media.divine.video';

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
