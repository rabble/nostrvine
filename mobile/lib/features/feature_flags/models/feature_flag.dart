// ABOUTME: Feature flag enum defining available feature flags for Divine
// ABOUTME: Provides type-safe flag definitions with display names and descriptions

enum FeatureFlag {
  newCameraUI('New Camera UI', 'Enhanced camera interface with new controls'),
  enhancedAnalytics(
    'Enhanced Analytics',
    'Detailed usage tracking and insights',
  ),
  newProfileLayout('New Profile Layout', 'Redesigned user profile screen'),
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
  profileListFeatures(
    'Profile List Features',
    'Enable people list creation from profiles and people list results in search (NIP-51 kind 30000)',
  ),
  contentPolicyV2(
    'Content Policy v2',
    'Parse-gated policy engine — filter blocked/muted authors at ingress',
  ),
  videoReplies(
    'Video Replies',
    'Enable recording and posting short video replies from comment threads',
  ),
  advancedRelaySettings(
    'Advanced Relay Settings',
    'Show Nostr relay configuration and diagnostics in Settings. '
        'Changing relays can break publishing and discovery — only turn '
        'this on if you know what you are doing.',
  ),
  ;

  const FeatureFlag(
    this.displayName,
    this.description,
  );

  final String displayName;
  final String description;
}
