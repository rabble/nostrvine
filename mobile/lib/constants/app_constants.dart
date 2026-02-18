// ABOUTME: System-wide constants and configuration values for divine
// ABOUTME: Centralized place for all app constants to avoid magic numbers and scattered values

/// System-wide constants for divine application
class AppConstants {
  // ============================================================================
  // NOSTR PUBKEYS
  // ============================================================================

  /// Classic Vines curator account pubkey (hex format)
  /// npub: npub1qvu80aqgpq6lzc5gqjp9jpmzczn4pzz3az87zexa3ypgwsu3fkjsj7mxlg
  /// Used as fallback content when users aren't following anyone
  static const String classicVinesPubkey =
      '033877f4080835f162880482590762c0a7508851e88fe164dd89028743914da5';

  /// Divine Team member 1 pubkey (hex format)
  /// npub: npub199wma3u7u7z5jmms8jty3ujxvew5dquur404stqrg269s0d9ej6qzewzu3
  static const String divineTeamPubkey1 =
      '295dbec79ee785496f703c9648f246665d46839c1d5f582c0342b4583da5ccb4';

  /// Divine Team member 2 pubkey (hex format)
  /// npub: npub1m9d23lqwl78y3z2jf9dcqeyer5nlh9hdsef0ztx7m3dyaz66u4qq4stysk
  static const String divineTeamPubkey2 =
      'd95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540';

  /// List of all Divine Team pubkeys
  static const List<String> divineTeamPubkeys = [
    divineTeamPubkey1,
    divineTeamPubkey2,
  ];

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

  /// Event ID for the official Editor's Picks curation list (kind 30005)
  /// This is a Nostr event containing the curated video list
  /// Published by: npub1wmrtrwj5f8yms3ekfha8g54flt8ktdtyarc53wfc0c0xvee09nlsqqr9pn
  static const String editorPicksEventId =
      '5e2797304dda04159f8f9f6c36cc5d7f473abe3931f21d7b68fed1ab6a04db3a';

  /// Maximum videos to show in Editor's Picks
  static const int editorPicksLimit = 25;

  /// Maximum videos to show in Trending
  static const int trendingLimit = 25;

  /// Maximum videos to show in Featured
  static const int featuredLimit = 25;

  /// Default pagination size for hashtags and explore sections
  static const int defaultPaginationSize = 25;

  // ============================================================================
  // PAGINATION THRESHOLDS
  // ============================================================================

  /// Minimum video count to consider "has more content" for initial load.
  /// Used by feed providers to determine if loadMore() should be enabled.
  /// If a feed returns fewer than this many videos, hasMoreContent = false.
  static const int hasMoreContentThreshold = 10;

  /// Batch size for loadMore pagination requests.
  /// Used to determine if more content is available based on response size.
  /// If API returns fewer than this many videos, no more content is available.
  static const int paginationBatchSize = 50;

  // ============================================================================
  // PRELOADING CONFIGURATION
  // ============================================================================

  /// Number of videos to preload before current position
  static const int preloadBefore = 2;

  /// Number of videos to preload after current position
  static const int preloadAfter = 3;

  /// Maximum videos to prefetch from grid views (approx 3x3 visible area)
  static const int gridPrefetchLimit = 9;

  /// Minimum bandwidth (Mbps) required for speculative grid prefetching
  static const double gridPrefetchMinBandwidthMbps = 1.5;

  // ============================================================================
  // NETWORK CONFIGURATION
  // ============================================================================

  /// Default Nostr relay URL
  static const String defaultRelayUrl = 'wss://relay.divine.video';

  /// Connection timeout for relay connections
  static const Duration relayConnectionTimeout = Duration(seconds: 30);

  /// Maximum subscription limit per relay
  static const int maxSubscriptionsPerRelay = 100;

  // ============================================================================
  // UI CONFIGURATION
  // ============================================================================

  /// Minimum swipe distance for video navigation
  static const double minSwipeDistance = 50;

  /// Animation duration for video transitions
  static const Duration videoTransitionDuration = Duration(milliseconds: 300);

  // ============================================================================
  // CACHE CONFIGURATION
  // ============================================================================

  /// Maximum number of video states to keep in memory
  static const int maxVideoStatesInMemory = 100;

  /// Maximum size of profile cache
  static const int maxProfileCacheSize = 1000;

  // ============================================================================
  // GEO-BLOCKING CONFIGURATION
  // ============================================================================

  /// Geo-blocking API endpoint URL
  static const String geoBlockApiUrl =
      'https://openvine-geo-blocker.protestnet.workers.dev';

  /// Cache duration for geo-blocking status (24 hours)
  static const Duration geoBlockCacheDuration = Duration(hours: 24);
}
