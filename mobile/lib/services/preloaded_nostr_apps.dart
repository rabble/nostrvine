// ABOUTME: Bundled starter catalog for vetted third-party Nostr app integrations
// ABOUTME: Gives Divine a curated baseline app list before remote directory data exists

import 'package:openvine/models/nostr_app_directory_entry.dart';

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

final List<NostrAppDirectoryEntry> preloadedNostrApps = List.unmodifiable([
  _buildPreloadedApp(
    id: 'bundled-flotilla',
    slug: 'flotilla',
    name: 'Flotilla',
    tagline: 'Nostr feeds and conversations in a lighter client.',
    description:
        'A curated third-party Nostr client surfaced inside Divine for lightweight social browsing.',
    launchUrl: 'https://app.flotilla.social/',
    sortOrder: 1,
  ),
  _buildPreloadedApp(
    id: 'bundled-habla',
    slug: 'habla',
    name: 'Habla',
    tagline: 'Long-form writing on Nostr.',
    description:
        'A curated third-party Nostr writing client for publishing and browsing articles.',
    launchUrl: 'https://habla.news/',
    sortOrder: 2,
  ),
  _buildPreloadedApp(
    id: 'bundled-zap-stream',
    slug: 'zap-stream',
    name: 'zap.stream',
    tagline: 'Live Nostr streaming and chats.',
    description:
        'A curated third-party Nostr live-streaming app for browsing streams and joining chats.',
    launchUrl: 'https://zap.stream/',
    sortOrder: 3,
  ),
  _buildPreloadedApp(
    id: 'bundled-primal',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages.',
    description:
        'A curated third-party Nostr client for timelines, replies, reactions, and direct messages.',
    launchUrl: 'https://primal.net/',
    sortOrder: 4,
  ),
  _buildPreloadedApp(
    id: 'bundled-yakihonne',
    slug: 'yakihonne',
    name: 'YakiHonne',
    tagline: 'Social timelines and publishing on Nostr.',
    description:
        'A curated third-party Nostr client for feeds, publishing, and profile-centric social activity.',
    launchUrl: 'https://yakihonne.com/',
    sortOrder: 5,
  ),
  _buildPreloadedApp(
    id: 'bundled-shopstr',
    slug: 'shopstr',
    name: 'Shopstr',
    tagline: 'A Nostr marketplace experience.',
    description:
        'A curated third-party Nostr marketplace surfaced inside Divine for commerce browsing.',
    launchUrl: 'https://shopstr.store/',
    sortOrder: 6,
  ),
  _buildPreloadedApp(
    id: 'bundled-nostrnests',
    slug: 'nostrnests',
    name: 'Nostr Nests',
    tagline: 'Shared Nostr spaces and live conversations.',
    description:
        'A curated third-party Nostr app for live spaces and community conversations.',
    launchUrl: 'https://nostrnests.com/',
    allowedSignEventKinds: [..._sharedSignEventKinds, 10312, 30312, 30313],
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
]);

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
  );
}
