import 'package:nostr_app_bridge_repository/src/models/nostr_app_directory_entry.dart';

const List<String> _sharedAllowedMethods = [
  'getPublicKey',
  'getRelays',
  'signEvent',
  'nip44.encrypt',
  'nip44.decrypt',
];

const List<String> _sharedPromptRequiredFor = [
  'signEvent',
  'nip44.encrypt',
  'nip44.decrypt',
];

const List<int> _sharedSignEventKinds = [
  1,
  6,
  7,
  14,
  15,
  1111,
  9734,
  30023,
];

/// Bundled starter catalog of vetted third-party Nostr apps.
///
/// Provides a curated baseline before the remote directory is
/// available.
final List<NostrAppDirectoryEntry> preloadedNostrApps = List.unmodifiable([
  _buildPreloadedApp(
    id: 'bundled-flotilla',
    slug: 'flotilla',
    name: 'Flotilla',
    tagline: 'Nostr feeds and conversations in a lighter client.',
    description:
        'A curated third-party Nostr client surfaced inside '
        'Divine for lightweight social browsing.',
    launchUrl: 'https://app.flotilla.social/',
    sortOrder: 1,
  ),
  _buildPreloadedApp(
    id: 'bundled-habla',
    slug: 'habla',
    name: 'Habla',
    tagline: 'Long-form writing on Nostr.',
    description:
        'A curated third-party Nostr writing client for '
        'publishing and browsing articles.',
    launchUrl: 'https://habla.news/',
    sortOrder: 2,
  ),
  _buildPreloadedApp(
    id: 'bundled-zap-stream',
    slug: 'zap-stream',
    name: 'zap.stream',
    tagline: 'Live Nostr streaming and chats.',
    description:
        'A curated third-party Nostr live-streaming app for '
        'browsing streams and joining chats.',
    launchUrl: 'https://zap.stream/',
    sortOrder: 3,
  ),
  _buildPreloadedApp(
    id: 'bundled-primal',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages.',
    description:
        'A curated third-party Nostr client for timelines, '
        'replies, reactions, and direct messages.',
    launchUrl: 'https://primal.net/',
    sortOrder: 4,
  ),
  _buildPreloadedApp(
    id: 'bundled-yakihonne',
    slug: 'yakihonne',
    name: 'YakiHonne',
    tagline: 'Social timelines and publishing on Nostr.',
    description:
        'A curated third-party Nostr client for feeds, '
        'publishing, and profile-centric social activity.',
    launchUrl: 'https://yakihonne.com/',
    sortOrder: 5,
  ),
  _buildPreloadedApp(
    id: 'bundled-shopstr',
    slug: 'shopstr',
    name: 'Shopstr',
    tagline: 'A Nostr marketplace experience.',
    description:
        'A curated third-party Nostr marketplace surfaced '
        'inside Divine for commerce browsing.',
    launchUrl: 'https://shopstr.store/',
    sortOrder: 6,
  ),
  _buildPreloadedApp(
    id: 'bundled-nostrnests',
    slug: 'nostrnests',
    name: 'Nostr Nests',
    tagline: 'Shared Nostr spaces and live conversations.',
    description:
        'A curated third-party Nostr app for live spaces '
        'and community conversations.',
    launchUrl: 'https://nostrnests.com/',
    allowedSignEventKinds: [
      ..._sharedSignEventKinds,
      10312,
      30312,
      30313,
    ],
    sortOrder: 7,
  ),
  _buildPreloadedApp(
    id: 'bundled-ditto',
    slug: 'ditto',
    name: 'ditto.pub',
    tagline: 'Posting and conversations on Nostr.',
    description:
        'A curated third-party Nostr client for browsing, posting, and conversations.',
    launchUrl: 'https://ditto.pub/',
    sortOrder: 8,
  ),
  _buildPreloadedApp(
    id: 'bundled-agora',
    slug: 'agora',
    name: 'Agora',
    tagline: 'Connect with activists worldwide.',
    description:
        'A curated third-party Nostr app for supporting activists and taking part in local actions.',
    launchUrl: 'https://agora.spot/',
    sortOrder: 9,
  ),
  _buildPreloadedApp(
    id: 'bundled-treasures',
    slug: 'treasures',
    name: 'Treasures',
    tagline: 'Decentralized geocaching on Nostr.',
    description:
        'A curated third-party Nostr app for discovering, hiding, and sharing geocaches.',
    launchUrl: 'https://treasures.to/',
    sortOrder: 10,
  ),
  _buildPreloadedApp(
    id: 'bundled-blobbi',
    slug: 'blobbi',
    name: 'Blobbi',
    tagline: 'A playful pet-themed social space on Nostr.',
    description:
        'A curated third-party Nostr client with a playful pet-forward social experience.',
    launchUrl: 'https://www.blobbi.pet/',
    sortOrder: 11,
  ),
  _buildPreloadedApp(
    id: 'bundled-espy',
    slug: 'espy',
    name: 'Espy',
    tagline: 'See beauty, share color.',
    description:
        'A curated third-party Nostr app for sharing colors and beautiful moments.',
    launchUrl: 'https://espy.you/',
    sortOrder: 12,
  ),
  _buildPreloadedApp(
    id: 'bundled-jumble',
    slug: 'jumble',
    name: 'Jumble',
    tagline: 'A user-friendly Nostr client for exploring relay feeds.',
    description:
        'A curated third-party Nostr client for browsing relay feeds in a simpler interface.',
    launchUrl: 'https://jumble.social/',
    sortOrder: 13,
  ),
  _buildPreloadedApp(
    id: 'bundled-divine-space',
    slug: 'divine-space',
    name: 'divine.space',
    tagline: 'A spatial Nostr experience.',
    description:
        'A curated third-party Nostr app offering a spatial take '
        'on social browsing and conversations.',
    launchUrl: 'https://divine.space/',
    sortOrder: 14,
  ),
]);

/// Per-app localStorage seeding scripts keyed by slug.
///
/// These scripts run after the NIP-07 bridge is installed.
/// Use `{{PUBKEY}}` as a placeholder for the user's hex pubkey.
/// The host replaces the placeholder at injection time.
/// Soapbox-based apps (Ditto, Nostr Nests) share the same localStorage
/// session format.
const String _soapboxAutoLoginScript = '''
localStorage.setItem('soapbox:auth:me', '{{PUBKEY}}');
localStorage.setItem('soapbox:auth:users', JSON.stringify({
  '{{PUBKEY}}': { type: 'extension' }
}));
''';

const Map<String, String> _autoLoginScripts = {
  // Primal reads loginType + pubkey from localStorage on page load
  // to auto-restore an extension session.
  'primal': '''
localStorage.setItem('loginMethod', 'extension');
localStorage.setItem('pubkey', '{{PUBKEY}}');
''',
  // Ditto and Nostr Nests share the @soapbox/soapbox login system.
  'ditto': _soapboxAutoLoginScript,
  'nostrnests': _soapboxAutoLoginScript,
  // zap.stream stores login method and pubkey for session restoration.
  'zap-stream': '''
localStorage.setItem('login-method', 'nip7');
localStorage.setItem('pubkey', '{{PUBKEY}}');
''',
};

NostrAppDirectoryEntry _buildPreloadedApp({
  required String id,
  required String slug,
  required String name,
  required String tagline,
  required String description,
  required String launchUrl,
  required int sortOrder,
  List<String> allowedMethods = _sharedAllowedMethods,
  List<int> allowedSignEventKinds = _sharedSignEventKinds,
  List<String> promptRequiredFor = _sharedPromptRequiredFor,
}) {
  final origin = Uri.parse(launchUrl).origin;

  return NostrAppDirectoryEntry(
    id: id,
    slug: slug,
    name: name,
    tagline: tagline,
    description: description,
    iconUrl: '$origin/favicon.ico',
    launchUrl: launchUrl,
    allowedOrigins: [origin],
    allowedMethods: allowedMethods,
    allowedSignEventKinds: allowedSignEventKinds,
    promptRequiredFor: promptRequiredFor,
    status: 'approved',
    sortOrder: sortOrder,
    createdAt: null,
    updatedAt: null,
    autoLoginScript: _autoLoginScripts[slug],
  );
}
