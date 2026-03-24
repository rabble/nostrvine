import test from 'node:test';
import assert from 'node:assert/strict';

import { serializeForm } from '../src/app-form.js';

function createForm() {
  return {
    elements: [
      { name: 'slug', value: 'primal' },
      { name: 'name', value: 'Primal' },
      { name: 'tagline', value: 'A Nostr social app' },
      { name: 'description', value: 'Browse and post to Nostr.' },
      { name: 'icon_url', value: 'https://primal.net/icon.png' },
      { name: 'launch_url', value: 'https://primal.net/app' },
      { name: 'status', value: 'approved' },
      { name: 'sort_order', value: '2' },
      { name: 'allowed_origins', value: 'https://primal.net' },
      { name: 'allowed_origins', value: ' https://beta.primal.net ' },
      { name: 'allowed_methods', value: 'getPublicKey' },
      { name: 'allowed_methods', value: 'signEvent' },
      { name: 'allowed_sign_event_kinds', value: '1' },
      { name: 'allowed_sign_event_kinds', value: '4' },
      { name: 'prompt_required_for', value: 'nip44.decrypt' },
    ],
  };
}

test('serializeForm normalizes manifest fields', () => {
  assert.deepEqual(serializeForm(createForm()), {
    slug: 'primal',
    name: 'Primal',
    tagline: 'A Nostr social app',
    description: 'Browse and post to Nostr.',
    icon_url: 'https://primal.net/icon.png',
    launch_url: 'https://primal.net/app',
    status: 'approved',
    sort_order: 2,
    allowed_origins: ['https://primal.net', 'https://beta.primal.net'],
    allowed_methods: ['getPublicKey', 'signEvent'],
    allowed_sign_event_kinds: [1, 4],
    prompt_required_for: ['nip44.decrypt'],
  });
});
