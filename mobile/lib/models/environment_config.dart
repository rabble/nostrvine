// ABOUTME: Environment configuration model for dev/staging/production switching
// ABOUTME: Each environment maps to exactly one relay URL and optional API base URL

/// Available app environments
enum AppEnvironment { production, productionNew, staging, dev }

/// Dev environment relay options
enum DevRelay { umbra, shugur, funnelcakeProd }

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
  /// Staging uses Divine Funnelcake relay (cake service)
  String get relayUrl {
    switch (environment) {
      case AppEnvironment.production:
        return 'wss://relay.divine.video';
      case AppEnvironment.productionNew:
        return 'wss://relay.dvines.org';
      case AppEnvironment.staging:
        return 'wss://relay.staging.dvines.org';
      case AppEnvironment.dev:
        switch (devRelay) {
          case DevRelay.umbra:
          case null:
            return 'wss://relay.poc.dvines.org';
          case DevRelay.shugur:
            return 'wss://shugur.poc.dvines.org';
          case DevRelay.funnelcakeProd:
            return 'wss://relay.dvines.org';
        }
    }
  }

  /// Get REST API base URL for video analytics (funnel service)
  /// Production uses relay.dvines.org, staging uses funnelcake.staging
  String? get apiBaseUrl {
    switch (environment) {
      case AppEnvironment.production:
        return 'https://relay.dvines.org';
      case AppEnvironment.productionNew:
        return 'https://relay.dvines.org';
      case AppEnvironment.staging:
        return 'https://relay.staging.dvines.org';
      case AppEnvironment.dev:
        // Only funnelcakeProd dev relay has REST API
        if (devRelay == DevRelay.funnelcakeProd) {
          return 'https://relay.dvines.org';
        }
        return null;
    }
  }

  /// Get blossom media server URL (same for all environments currently)
  String get blossomUrl => 'https://media.divine.video';

  /// Whether this is production environment
  bool get isProduction =>
      environment == AppEnvironment.production ||
      environment == AppEnvironment.productionNew;

  /// Human readable display name
  String get displayName {
    switch (environment) {
      case AppEnvironment.production:
        return 'Production';
      case AppEnvironment.productionNew:
        return 'Production (Funnelcake)';
      case AppEnvironment.staging:
        return 'Staging (Funnelcake)';
      case AppEnvironment.dev:
        switch (devRelay) {
          case DevRelay.umbra:
          case null:
            return 'Dev - Umbra';
          case DevRelay.shugur:
            return 'Dev - Shugur';
          case DevRelay.funnelcakeProd:
            return 'Dev - Funnelcake Prod';
        }
    }
  }

  /// Color for environment indicator (as int for const constructor)
  int get indicatorColorValue {
    switch (environment) {
      case AppEnvironment.production:
        return 0xFF4CAF50; // Green
      case AppEnvironment.productionNew:
        return 0xFF2196F3; // Blue (Funnelcake production)
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
