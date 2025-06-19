// ABOUTME: Application configuration including backend URLs and environment settings
// ABOUTME: Centralizes app configuration for different environments (dev, staging, prod)

class AppConfig {
  // Backend configuration
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://nostrvine-backend.protestnet.workers.dev',
  );
  
  // Environment detection
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );
  
  // Development mode flag
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  
  // API endpoints
  static String get healthUrl => '$backendBaseUrl/health';
  static String get nip96InfoUrl => '$backendBaseUrl/.well-known/nostr/nip96.json';
  
  // Stream CDN endpoints (new Cloudflare Stream integration)
  static String get streamUploadRequestUrl => '$backendBaseUrl/v1/media/request-upload';
  static String streamStatusUrl(String videoId) => '$backendBaseUrl/v1/media/status/$videoId';
  static String get streamWebhookUrl => '$backendBaseUrl/v1/webhooks/stream-complete';
  
  // Legacy endpoints (for backward compatibility)
  static String get cloudinarySignedUploadUrl => '$backendBaseUrl/v1/media/request-upload';
  static String get videoMetadataUrl => '$backendBaseUrl/v1/media/metadata';
  static String get videoListUrl => '$backendBaseUrl/v1/media/list';
  
  // App configuration
  static const String appName = 'NostrVine';
  static const String appVersion = '1.0.0';
  
  // Nostr configuration
  static const List<String> defaultNostrRelays = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.nos.social',
    'wss://relay.nostr.band',
    'wss://cache2.primal.net/v1',
  ];
  
  // Debugging
  static bool get enableDebugLogs => isDevelopment;
  
  // Feature flags
  static bool get enableStreamCDN => true; // New Cloudflare Stream integration
  static bool get enableCloudinaryUpload => false; // Legacy fallback
  static bool get enableNIP96Upload => false; // Iceboxed for MVP
  static bool get enableOfflineQueue => true;
  
  /// Get configuration summary for debugging
  static Map<String, dynamic> getConfigSummary() {
    return {
      'environment': environment,
      'backendUrl': backendBaseUrl,
      'isDevelopment': isDevelopment,
      'isProduction': isProduction,
      'enableStreamCDN': enableStreamCDN,
      'enableCloudinaryUpload': enableCloudinaryUpload,
      'enableNIP96Upload': enableNIP96Upload,
      'relayCount': defaultNostrRelays.length,
    };
  }
}