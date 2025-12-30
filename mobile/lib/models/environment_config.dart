// ABOUTME: Environment configuration model for dev/staging/production switching
// ABOUTME: Each environment maps to exactly one relay URL

/// Available app environments
enum AppEnvironment { production, staging, dev }

/// Dev environment relay options
enum DevRelay { umbra, shugur }

/// Configuration for the current app environment
class EnvironmentConfig {
  const EnvironmentConfig({required this.environment, this.devRelay});

  final AppEnvironment environment;
  final DevRelay? devRelay;

  /// Default production configuration
  static const production = EnvironmentConfig(
    environment: AppEnvironment.production,
  );

  /// Get relay URL for current environment (always exactly one)
  String get relayUrl {
    switch (environment) {
      case AppEnvironment.production:
        return 'wss://relay.divine.video';
      case AppEnvironment.staging:
        return 'wss://staging-relay.divine.video';
      case AppEnvironment.dev:
        switch (devRelay) {
          case DevRelay.umbra:
          case null:
            return 'wss://relay.poc.dvines.org';
          case DevRelay.shugur:
            return 'wss://shugur.poc.dvines.org';
        }
    }
  }

  /// Get blossom media server URL (same for all environments currently)
  String get blossomUrl => 'https://media.divine.video';

  /// Whether this is production environment
  bool get isProduction => environment == AppEnvironment.production;

  /// Human readable display name
  String get displayName {
    switch (environment) {
      case AppEnvironment.production:
        return 'Production';
      case AppEnvironment.staging:
        return 'Staging';
      case AppEnvironment.dev:
        switch (devRelay) {
          case DevRelay.umbra:
          case null:
            return 'Dev - Umbra';
          case DevRelay.shugur:
            return 'Dev - Shugur';
        }
    }
  }

  /// Color for environment indicator (as int for const constructor)
  int get indicatorColorValue {
    switch (environment) {
      case AppEnvironment.production:
        return 0xFF4CAF50; // Green
      case AppEnvironment.staging:
        return 0xFFFFC107; // Yellow/Amber
      case AppEnvironment.dev:
        return 0xFFFF9800; // Orange
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvironmentConfig &&
          environment == other.environment &&
          devRelay == other.devRelay;

  @override
  int get hashCode => Object.hash(environment, devRelay);
}
