// ABOUTME: Application configuration including backend URLs and environment settings
// ABOUTME: Centralizes app configuration for different environments (dev, staging, prod)

class AppConfig {
  // Backend configuration
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://api.openvine.co',
  );

  static const String inviteServerBaseUrl = String.fromEnvironment(
    'INVITE_SERVER_URL',
    defaultValue: 'https://invite.divine.video',
  );

  static const String appsDirectoryBaseUrl = String.fromEnvironment(
    'APPS_DIRECTORY_URL',
    defaultValue: 'https://apps.divine.video',
  );

  // Environment detection
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  // Development mode flag
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';
  static bool get isProduction => environment == 'production';
  static const bool isGhActionsPrPreviewBuild = bool.fromEnvironment(
    'GH_ACTIONS_PR_PREVIEW',
  );

  // API endpoints
  static String get healthUrl => '$backendBaseUrl/health';
  static String get nip96InfoUrl =>
      '$backendBaseUrl/.well-known/nostr/nip96.json';

  static String get streamUploadRequestUrl =>
      '$backendBaseUrl/v1/media/request-upload';
  static String streamStatusUrl(String videoId) =>
      '$backendBaseUrl/v1/media/status/$videoId';
  static String get streamWebhookUrl =>
      '$backendBaseUrl/v1/webhooks/stream-complete';

  // Cloudinary endpoints
  static String get cloudinarySignedUploadUrl =>
      '$backendBaseUrl/v1/media/cloudinary/request-upload';
  static String get cloudinaryWebhookUrl => '$backendBaseUrl/v1/media/webhook';
  static String get readyEventsUrl => '$backendBaseUrl/v1/media/ready-events';

  // App configuration
  static const String appName = 'Divine';
  static const String appVersion = '1.0.0';

  // Relay configuration handled by NostrClient

  // Debugging
  static bool get enableDebugLogs => isDevelopment;

  // Feature flags - Multi-agent development coordination
  static bool get enableStreamCDN => _getBoolFlag('ENABLE_STREAM_CDN', true);
  static bool get enableCloudinaryUpload =>
      _getBoolFlag('ENABLE_CLOUDINARY', false);
  static bool get enableNIP96Upload => _getBoolFlag('ENABLE_NIP96', false);
  static bool get enableOfflineQueue =>
      _getBoolFlag('ENABLE_OFFLINE_QUEUE', true);

  // Multi-agent development flags
  static bool get enableCameraOptimizations =>
      _getBoolFlag('ENABLE_CAMERA_OPTIMIZATIONS', false);
  static bool get enableVideoProcessingPipeline =>
      _getBoolFlag('ENABLE_VIDEO_PIPELINE', false);
  static bool get enableMetadataCaching =>
      _getBoolFlag('ENABLE_METADATA_CACHE', false);
  static bool get enableUIImprovements =>
      _getBoolFlag('ENABLE_UI_IMPROVEMENTS', false);

  // Helper for environment-based feature flags
  static bool _getBoolFlag(String envKey, bool defaultValue) {
    final value = const String.fromEnvironment('').isEmpty
        ? ''
        : const String.fromEnvironment('FLUTTER_TEST') == 'true'
        ? '' // Return empty for tests to use default
        : String.fromEnvironment(envKey);
    if (value.isEmpty) return defaultValue;
    return value.toLowerCase() == 'true';
  }

  /// Get configuration summary for debugging
  static Map<String, dynamic> getConfigSummary() => {
    'environment': environment,
    'backendUrl': backendBaseUrl,
    'inviteServerUrl': inviteServerBaseUrl,
    'appsDirectoryUrl': appsDirectoryBaseUrl,
    'isDevelopment': isDevelopment,
    'isProduction': isProduction,
    'isGhActionsPrPreviewBuild': isGhActionsPrPreviewBuild,
    'enableStreamCDN': enableStreamCDN,
    'enableCloudinaryUpload': enableCloudinaryUpload,
    'enableNIP96Upload': enableNIP96Upload,
    // External relay configuration DELETED
    // Multi-agent development flags
    'enableCameraOptimizations': enableCameraOptimizations,
    'enableVideoProcessingPipeline': enableVideoProcessingPipeline,
    'enableMetadataCaching': enableMetadataCaching,
    'enableUIImprovements': enableUIImprovements,
  };
}
