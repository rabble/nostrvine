// ABOUTME: System-wide constants and configuration values for OpenVine
// ABOUTME: Centralized place for all app constants to avoid magic numbers and scattered values

/// System-wide constants for OpenVine application
class AppConstants {
  
  // ============================================================================
  // NOSTR PUBKEYS
  // ============================================================================
  
  /// Classic Vines curator account pubkey (hex format)
  /// npub: npub1944q7fcyxp2efr6w958lyq7szysn3l7njje2rj20nksadktldygsq0dhv0
  /// Used as fallback content when users aren't following anyone
  static const String classicVinesPubkey = '2d6a0f27043055948f4e2d0ff203d0112138ffd394b2a1c94f9da1d6d97f6911';
  
  // ============================================================================
  // FEED CONFIGURATION
  // ============================================================================
  
  /// Default limit for following feed subscriptions
  static const int followingFeedLimit = 500;
  
  /// Default limit for discovery feed subscriptions  
  static const int discoveryFeedLimit = 500;
  
  /// Minimum following videos needed before loading discovery feed
  static const int followingVideoThreshold = 5;
  
  // ============================================================================
  // VIDEO PROCESSING
  // ============================================================================
  
  /// Maximum retry attempts for video loading
  static const int maxVideoRetryAttempts = 3;
  
  /// Retry delay for video operations
  static const Duration videoRetryDelay = Duration(seconds: 10);
  
  // ============================================================================
  // CURATION SETS
  // ============================================================================
  
  /// Maximum videos to show in Editor's Picks
  static const int editorPicksLimit = 20;
  
  /// Maximum videos to show in Trending
  static const int trendingLimit = 12;
  
  /// Maximum videos to show in Featured  
  static const int featuredLimit = 12;
  
  // ============================================================================
  // PRELOADING CONFIGURATION
  // ============================================================================
  
  /// Number of videos to preload before current position
  static const int preloadBefore = 2;
  
  /// Number of videos to preload after current position
  static const int preloadAfter = 3;
  
  // ============================================================================
  // NETWORK CONFIGURATION
  // ============================================================================
  
  /// Connection timeout for relay connections
  static const Duration relayConnectionTimeout = Duration(seconds: 30);
  
  /// Maximum subscription limit per relay
  static const int maxSubscriptionsPerRelay = 100;
  
  // ============================================================================
  // UI CONFIGURATION
  // ============================================================================
  
  /// Minimum swipe distance for video navigation
  static const double minSwipeDistance = 50.0;
  
  /// Animation duration for video transitions
  static const Duration videoTransitionDuration = Duration(milliseconds: 300);
  
  // ============================================================================
  // CACHE CONFIGURATION
  // ============================================================================
  
  /// Maximum number of video states to keep in memory
  static const int maxVideoStatesInMemory = 100;
  
  /// Maximum size of profile cache
  static const int maxProfileCacheSize = 1000;
}