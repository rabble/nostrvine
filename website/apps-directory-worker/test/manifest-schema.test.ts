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
        allowed_origins: ['https://primal.net'],
        allowed_methods: ['getPublicKey', 'signEvent'],
        allowed_sign_event_kinds: [1],
        status: 'approved',
      }),
    ).toEqual({
      slug: 'primal',
      allowed_origins: ['https://primal.net'],
      allowed_methods: ['getPublicKey', 'signEvent'],
      allowed_sign_event_kinds: [1],
      status: 'approved',
      prompt_required_for: [],
    });
  });

  it('rejects empty origins', () => {
    expect(() =>
      validateManifest({
        slug: 'primal',
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
        allowed_origins: ['https://primal.net'],
        allowed_methods: ['nip04.encrypt'],
        allowed_sign_event_kinds: [1],
        status: 'approved',
      }),
    ).toThrow('allowed_methods');
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
