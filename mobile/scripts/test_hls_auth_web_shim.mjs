import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(
  'packages/hls_auth_web_player/web/hls_auth_web_player.js',
  'utf8',
);

const fetchCalls = [];
const revokedUrls = [];
let blobCounter = 0;
let nextResponse = { status: 200, ok: true };

globalThis.window = globalThis;
globalThis.fetch = async (url, init) => {
  fetchCalls.push({ url, init });
  return {
    status: nextResponse.status,
    ok: nextResponse.ok,
    blob: async () => ({ id: `blob-${blobCounter}` }),
  };
};
globalThis.URL = {
  createObjectURL(blob) {
    blobCounter += 1;
    return `blob://test/${blob.id}/${blobCounter}`;
  },
  revokeObjectURL(url) {
    revokedUrls.push(url);
  },
};

vm.runInThisContext(source, { filename: 'hls_auth_web_player.js' });

assert.equal(typeof window.__divineRegisterVideo, 'function');
assert.equal(typeof window.__divineFetchMp4, 'function');
assert.equal(typeof window.__divineDisposeView, 'function');

const missingViewResult = await window.__divineFetchMp4(
  'missing-view',
  'https://cdn.example/video.mp4',
  'NIP98 missing',
);
assert.deepEqual(missingViewResult, { status: 'failure' });

const video = {
  src: '',
  paused: false,
  pauseCalled: false,
  loadCalled: false,
  pause() {
    this.pauseCalled = true;
    this.paused = true;
  },
  load() {
    this.loadCalled = true;
  },
  removeAttribute(name) {
    if (name === 'src') {
      this.src = '';
    }
  },
};

window.__divineRegisterVideo('test-view', video);

nextResponse = { status: 401, ok: false };
const requiresAuthResult = await window.__divineFetchMp4(
  'test-view',
  'https://cdn.example/protected.mp4',
  'NIP98 protected',
);
assert.deepEqual(requiresAuthResult, { status: 'requiresAuth', code: 401 });
assert.equal(
  fetchCalls.at(-1).init.headers.Authorization,
  'NIP98 protected',
);
assert.equal(video.src, '');

nextResponse = { status: 200, ok: true };
const firstOkResult = await window.__divineFetchMp4(
  'test-view',
  'https://cdn.example/video.mp4',
  'NIP98 first',
);
assert.deepEqual(firstOkResult, { status: 'ok' });
assert.match(video.src, /^blob:\/\/test\/blob-0\/1$/);
const firstBlobUrl = video.src;

const secondOkResult = await window.__divineFetchMp4(
  'test-view',
  'https://cdn.example/video.mp4',
  'NIP98 second',
);
assert.deepEqual(secondOkResult, { status: 'ok' });
assert.match(video.src, /^blob:\/\/test\/blob-1\/2$/);
assert.deepEqual(revokedUrls, [firstBlobUrl]);

window.__divineDisposeView('test-view');
assert.equal(video.pauseCalled, true);
assert.equal(video.loadCalled, true);
assert.equal(video.src, '');
assert.deepEqual(revokedUrls, [firstBlobUrl, 'blob://test/blob-1/2']);

console.log('hls_auth_web_player.js smoke test passed');
