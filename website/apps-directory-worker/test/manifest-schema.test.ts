import { describe, expect, it } from 'vitest';

import {
  SUPPORTED_METHODS,
  validateManifest,
} from '../src/lib/manifest-schema';

describe('manifest schema', () => {
  it('validates a supported manifest', () => {
    expect(
      validateManifest({
        slug: 'primal',
        name: 'Primal',
        tagline: 'A Nostr social app',
        description: 'Browse and post to Nostr.',
        icon_url: 'https://primal.net/icon.png',
        launch_url: 'https://primal.net/app',
        allowed_origins: ['https://primal.net'],
        allowed_methods: ['getPublicKey', 'signEvent'],
        allowed_sign_event_kinds: [1],
        prompt_required_for: ['nip44.decrypt'],
        status: 'approved',
        sort_order: 4,
      }),
    ).toEqual({
      slug: 'primal',
      name: 'Primal',
      tagline: 'A Nostr social app',
      description: 'Browse and post to Nostr.',
      icon_url: 'https://primal.net/icon.png',
      launch_url: 'https://primal.net/app',
      allowed_origins: ['https://primal.net'],
      allowed_methods: ['getPublicKey', 'signEvent'],
      allowed_sign_event_kinds: [1],
      prompt_required_for: ['nip44.decrypt'],
      status: 'approved',
      sort_order: 4,
    });
  });

  it('rejects empty origins', () => {
    expect(() =>
      validateManifest({
        slug: 'primal',
        name: 'Primal',
        launch_url: 'https://primal.net/app',
        allowed_origins: [''],
        allowed_methods: ['getPublicKey'],
        allowed_sign_event_kinds: [1],
        status: 'approved',
      }),
    ).toThrow('allowed_origins');
  });

  it('rejects non-https origins', () => {
    expect(() =>
      validateManifest({
        slug: 'primal',
        name: 'Primal',
        launch_url: 'https://primal.net/app',
        allowed_origins: ['http://primal.net'],
        allowed_methods: ['getPublicKey'],
        allowed_sign_event_kinds: [1],
        status: 'approved',
      }),
    ).toThrow('allowed_origins');
  });

  it('rejects unsupported methods', () => {
    expect(() =>
      validateManifest({
        slug: 'primal',
        name: 'Primal',
        launch_url: 'https://primal.net/app',
        allowed_origins: ['https://primal.net'],
        allowed_methods: ['nip04.encrypt'],
        allowed_sign_event_kinds: [1],
        status: 'approved',
      }),
    ).toThrow('allowed_methods');
  });

  it('rejects missing launch metadata', () => {
    expect(() =>
      validateManifest({
        slug: 'primal',
        allowed_origins: ['https://primal.net'],
        allowed_methods: ['getPublicKey'],
        allowed_sign_event_kinds: [1],
        status: 'approved',
      }),
    ).toThrow('name');
  });

  it('contains the supported method contract', () => {
    expect(SUPPORTED_METHODS).toEqual([
      'getPublicKey',
      'signEvent',
      'nip44.encrypt',
      'nip44.decrypt',
    ]);
  });
});
