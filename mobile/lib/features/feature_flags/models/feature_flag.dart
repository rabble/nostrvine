// ABOUTME: Feature flag enum defining available feature flags for Divine
// ABOUTME: Provides type-safe flag definitions with display names and descriptions

enum FeatureFlagAudience { user, internal }

enum FeatureFlag {
  enhancedAnalytics(
    'Enhanced Analytics',
    'Detailed usage tracking and insights',
  ),
  debugTools('Debug Tools', 'Developer debugging utilities and diagnostics'),
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
  publishDmRelayList(
    'Publish DM Relay List',
    'Self-advertise your NIP-17 kind-10050 DM inbox relays on login so '
        'compliant senders deliver where divine reads. Keep off until the '
        'backend relay accepts kind-10050.',
    audience: FeatureFlagAudience.internal,
  ),
  feedTuning(
    'Feed Tuning Swipes',
    'Swipe left/right on the fullscreen feed to send "less/more like this" '
        'signals that personalize recommendations. Off by default until the '
        'relay and recommendation backend are ready.',
  ),
  profileMonetizationLinks(
    'Profile Monetization Links',
    'Enable outbound tip and subscription links on profiles.',
  ),
  lightMode(
    'Light Mode',
    'Enable the experimental System, Light, and Dark appearance settings. '
        'Accent pills and category tiles still render dark on a light page.',
  ),
  adaptiveMediaChrome(
    'Adaptive Media Chrome',
    'Use light controls around fullscreen video when Light Mode is enabled.',
    audience: FeatureFlagAudience.internal,
  ),
  communityContentWarnings(
    'Community Content Warnings',
    'Suggest content-warning labels on videos and blur videos whose labels '
        'crossed the community threshold. Off by default pending T&S '
        'rollout sign-off.',
    audience: FeatureFlagAudience.internal,
  ),
  emailVerificationPinFallback(
    'Email Verification PIN Fallback',
    'Show the in-app email verification PIN and resend fallback. Off by '
        'default until keycast verify-pin support is deployed.',
    audience: FeatureFlagAudience.internal,
  ),
  divineSupporters(
    'Divine Supporters',
    'Optional monthly supporter subscription via in-app purchase. '
        'Nothing is gated — it keeps Divine running and recognizes supporters.',
  ),
  newPostNotifications(
    'New Post Notifications',
    'Turn on a bell for creators you follow to get notified when they post. '
        'Off by default until the push service fans out kind 34236 to '
        'subscribers — with it off, the bell would publish a subscription '
        'that nothing ever delivers.',
  );

  const FeatureFlag(
    this.displayName,
    this.description, {
    this.audience = FeatureFlagAudience.user,
  });

  final String displayName;
  final String description;
  final FeatureFlagAudience audience;

  bool get isInternal => audience == FeatureFlagAudience.internal;
}
