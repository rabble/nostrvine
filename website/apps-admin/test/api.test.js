import test from 'node:test';
import assert from 'node:assert/strict';

import { saveApp } from '../src/api.js';

test('saveApp uses POST for new manifests', async () => {
  const calls = [];
  globalThis.fetch = async (url, options) => {
    calls.push({ url, options });
    return {
      ok: true,
      async json() {
        return { id: 1, slug: 'primal' };
      },
    };
  };

  const result = await saveApp({ slug: 'primal', status: 'draft' });

  assert.deepEqual(result, { id: 1, slug: 'primal' });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, '/v1/admin/apps');
  assert.equal(calls[0].options.method, 'POST');
});

test('saveApp uses PUT for existing manifests', async () => {
  const calls = [];
  globalThis.fetch = async (url, options) => {
    calls.push({ url, options });
    return {
      ok: true,
      async json() {
        return { id: 42, slug: 'primal' };
      },
    };
  };

  const result = await saveApp({ id: 42, slug: 'primal', status: 'approved' });

  assert.deepEqual(result, { id: 42, slug: 'primal' });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, '/v1/admin/apps/42');
  assert.equal(calls[0].options.method, 'PUT');
});
