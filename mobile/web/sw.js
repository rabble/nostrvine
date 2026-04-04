// ABOUTME: Self-unregistering stub replacing the former cache-first OpenVine service worker.
// ABOUTME: The previous SW pinned non-hashed Flutter entrypoints with a CACHE_NAME that never
// ABOUTME: bumped, stranding returning users on stale builds. This stub wipes all caches and
// ABOUTME: unregisters itself so existing clients self-heal on their next visit.

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const names = await caches.keys();
      await Promise.all(names.map((n) => caches.delete(n)));
    } catch (_) {
      // Best-effort cache teardown; continue to unregister regardless.
    }
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    clients.forEach((c) => {
      try {
        c.navigate(c.url);
      } catch (_) {
        // Some clients (e.g. cross-origin) may refuse navigation; ignore.
      }
    });
  })());
});
