import test from 'node:test';
import assert from 'node:assert/strict';

import { serializeForm } from '../src/app-form.js';

function createForm() {
  return {
    elements: [
      { name: 'slug', value: 'primal' },
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
    allowed_origins: ['https://primal.net', 'https://beta.primal.net'],
    allowed_methods: ['getPublicKey', 'signEvent'],
    allowed_sign_event_kinds: [1, 4],
    prompt_required_for: ['nip44.decrypt'],
  });
});
