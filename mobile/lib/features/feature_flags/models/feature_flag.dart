// ABOUTME: Feature flag enum defining available feature flags for Divine
// ABOUTME: Provides type-safe flag definitions with display names and descriptions

enum FeatureFlag {
  newCameraUI('New Camera UI', 'Enhanced camera interface with new controls'),
  enhancedVideoPlayer(
    'Enhanced Video Player',
    'Improved video playback engine with better performance',
  ),
  enhancedAnalytics(
    'Enhanced Analytics',
    'Detailed usage tracking and insights',
  ),
  newProfileLayout('New Profile Layout', 'Redesigned user profile screen'),
  livestreamingBeta(
    'Livestreaming Beta',
    'Live video streaming feature (beta)',
  ),
  debugTools('Debug Tools', 'Developer debugging utilities and diagnostics'),
  routerDrivenHome(
    'Router-Driven Home Screen',
    'New router-driven home screen architecture (eliminates lifecycle bugs)',
  ),
  enableVideoEditorV1(
    'Video Editor V1',
    'Enable video editing functionality (disabled on web, enabled on native platforms)',
  ),
  classicsHashtags(
    'Classics Trending Hashtags',
    'Show trending hashtags section on the Classics tab',
  ),
  curatedLists('Curated Lists', 'Enable curated lists feature in share menu'),
  blueskyPublishing(
    'Bluesky Publishing',
    'Enable Bluesky crosspost toggle in settings',
  ),
  integratedApps(
    'Integrated Apps',
    'Enable the integrated Nostr apps directory and sandbox',
  ),
  accountSwitching(
    'Account Switching',
    'Enable switching between remembered accounts in Settings',
  ),
  hlsAuthWebPlayer(
    'HLS + NIP-98 Web Player',
    'Route web video playback through hls.js with NIP-98 auth headers so '
        'age-gated and other 401-protected media can be viewed on web',
  ),
  peopleListSearch(
    'People List Search',
    'Show people list (kind 30000) results alongside video lists in search',
  ),
  contentPolicyV2(
    'Content Policy v2',
    'Parse-gated policy engine — filter blocked/muted authors at ingress',
  )
  ;

  const FeatureFlag(this.displayName, this.description);

  final String displayName;
  final String description;
}
