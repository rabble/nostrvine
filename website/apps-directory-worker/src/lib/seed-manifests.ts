import type { AppManifest } from './manifest-schema';

const sharedAllowedMethods: AppManifest['allowed_methods'] = [
  'getPublicKey',
  'getRelays',
  'signEvent',
  'nip44.encrypt',
  'nip44.decrypt',
];

const sharedPromptRequiredFor: AppManifest['prompt_required_for'] = [
  'signEvent',
  'nip44.encrypt',
  'nip44.decrypt',
];

const sharedSignEventKinds: AppManifest['allowed_sign_event_kinds'] = [
  1,
  6,
  7,
  14,
  15,
  1111,
  9734,
  30023,
];

function buildSeedManifest({
  slug,
  name,
  tagline,
  description,
  launchUrl,
  allowedSignEventKinds = sharedSignEventKinds,
  sortOrder,
}: {
  slug: string;
  name: string;
  tagline: string;
  description: string;
  launchUrl: string;
  allowedSignEventKinds?: AppManifest['allowed_sign_event_kinds'];
  sortOrder: number;
}): AppManifest {
  const origin = new URL(launchUrl).origin;

  return {
    slug,
    name,
    tagline,
    description,
    icon_url: `${origin}/favicon.ico`,
    launch_url: launchUrl,
    allowed_origins: [origin],
    allowed_methods: [...sharedAllowedMethods],
    allowed_sign_event_kinds: [...allowedSignEventKinds],
    prompt_required_for: [...sharedPromptRequiredFor],
    status: 'approved',
    sort_order: sortOrder,
  };
}

export const seedManifests: AppManifest[] = [
  buildSeedManifest({
    slug: 'flotilla',
    name: 'Flotilla',
    tagline: 'Nostr feeds and conversations in a lighter client.',
    description:
      'A vetted Nostr client launched from Divine for lightweight social browsing.',
    launchUrl: 'https://app.flotilla.social/',
    sortOrder: 1,
  }),
  buildSeedManifest({
    slug: 'habla',
    name: 'Habla',
    tagline: 'Long-form writing on Nostr.',
    description:
      'A vetted long-form Nostr writing client that can publish and browse articles.',
    launchUrl: 'https://habla.news/',
    sortOrder: 2,
  }),
  buildSeedManifest({
    slug: 'zap-stream',
    name: 'zap.stream',
    tagline: 'Live Nostr streaming and chats.',
    description:
      'A vetted live-streaming client for browsing streams and interacting over Nostr.',
    launchUrl: 'https://zap.stream/',
    sortOrder: 3,
  }),
  buildSeedManifest({
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages.',
    description:
      'A vetted Nostr client for timelines, replies, reactions, and direct messages.',
    launchUrl: 'https://primal.net/',
    sortOrder: 4,
  }),
  buildSeedManifest({
    slug: 'yakihonne',
    name: 'YakiHonne',
    tagline: 'Social timelines and publishing on Nostr.',
    description:
      'A vetted Nostr client for feeds, publishing, and profile-centric social activity.',
    launchUrl: 'https://yakihonne.com/',
    sortOrder: 5,
  }),
  buildSeedManifest({
    slug: 'shopstr',
    name: 'Shopstr',
    tagline: 'A Nostr marketplace experience.',
    description:
      'A vetted Nostr commerce app surfaced inside Divine for marketplace browsing.',
    launchUrl: 'https://shopstr.store/',
    sortOrder: 6,
  }),
  buildSeedManifest({
    slug: 'nostrnests',
    name: 'Nostr Nests',
    tagline: 'Shared Nostr spaces and live conversations.',
    description:
      'A vetted Nostr app for live spaces and community conversations.',
    launchUrl: 'https://nostrnests.com/',
    allowedSignEventKinds: [...sharedSignEventKinds, 10312, 30312, 30313],
    sortOrder: 7,
  }),
];
