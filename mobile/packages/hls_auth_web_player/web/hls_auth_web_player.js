// ABOUTME: Browser-side shim for hls_auth_web_player. Bridges hls.js +
// NIP-98 auth header generation to a Dart callback; manages video element
// lifecycle (src assignment, blob revocation, hls.js destroy).

(function () {
  'use strict';

  // Per-viewType state: { video, hls, blobUrl }.
  const views = Object.create(null);

  function registerVideo(viewType, video) {
    views[viewType] = views[viewType] || {};
    views[viewType].video = video;
  }

  // Returns a constructor that hls.js accepts as `config.loader`. The
  // constructor subclasses the default loader and attaches an Authorization
  // header to each XHR context after resolving the async Dart callback.
  function createAuthLoaderFactory(getAuthHeader) {
    if (typeof window.Hls === 'undefined') {
      throw new Error('hls.js not loaded');
    }
    const DefaultLoader = window.Hls.DefaultConfig.loader;

    function AuthLoader(config) {
      DefaultLoader.call(this, config);
    }
    AuthLoader.prototype = Object.create(DefaultLoader.prototype);
    AuthLoader.prototype.constructor = AuthLoader;

    AuthLoader.prototype.load = function (context, config, callbacks) {
      const loader = this;
      Promise.resolve()
        .then(function () {
          return getAuthHeader(context.url, 'GET');
        })
        .then(function (authHeader) {
          if (authHeader) {
            if (!context.headers) {
              context.headers = {};
            }
            context.headers['Authorization'] = authHeader;
          }
        })
        .catch(function (error) {
          // Swallow — downstream load will still run; server may 401.
          // eslint-disable-next-line no-console
          console.error('[hls_auth_web_player] auth header error:', error);
        })
        .finally(function () {
          DefaultLoader.prototype.load.call(loader, context, config, callbacks);
        });
    };

    return AuthLoader;
  }

  async function fetchMp4(viewType, url, authorization) {
    const state = views[viewType];
    if (!state || !state.video) {
      return { status: 'failure' };
    }
    const headers = {};
    if (authorization) {
      headers['Authorization'] = authorization;
    }
    try {
      const response = await fetch(url, { method: 'GET', headers });
      if (response.status === 401 || response.status === 403) {
        return { status: 'requiresAuth', code: response.status };
      }
      if (!response.ok) {
        return { status: 'failure', code: response.status };
      }
      const blob = await response.blob();
      if (state.blobUrl) {
        URL.revokeObjectURL(state.blobUrl);
      }
      const blobUrl = URL.createObjectURL(blob);
      state.blobUrl = blobUrl;
      state.video.src = blobUrl;
      return { status: 'ok' };
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('[hls_auth_web_player] fetchMp4 failure:', error);
      return { status: 'failure' };
    }
  }

  function loadHls(viewType, url, getAuthHeader) {
    return new Promise(function (resolve) {
      const state = views[viewType];
      if (!state || !state.video) {
        resolve({ status: 'failure' });
        return;
      }
      if (typeof window.Hls === 'undefined' || !window.Hls.isSupported()) {
        resolve({ status: 'failure' });
        return;
      }
      if (state.hls) {
        try {
          state.hls.destroy();
        } catch (_) {
          /* ignore */
        }
        state.hls = null;
      }
      const loaderCtor = createAuthLoaderFactory(getAuthHeader);
      const hls = new window.Hls({
        enableWorker: true,
        lowLatencyMode: false,
        backBufferLength: 90,
        maxBufferLength: 30,
        startLevel: -1,
        capLevelToPlayerSize: true,
        loader: loaderCtor,
      });
      state.hls = hls;
      let settled = false;

      hls.on(window.Hls.Events.MANIFEST_PARSED, function () {
        if (settled) return;
        settled = true;
        resolve({ status: 'ok' });
      });
      hls.on(window.Hls.Events.ERROR, function (_event, data) {
        if (settled) return;
        if (data && data.response) {
          const code = data.response.code;
          if (code === 401 || code === 403) {
            settled = true;
            try { hls.destroy(); } catch (_) { /* ignore */ }
            state.hls = null;
            resolve({ status: 'requiresAuth', code: code });
            return;
          }
        }
        if (data && data.fatal) {
          settled = true;
          try { hls.destroy(); } catch (_) { /* ignore */ }
          state.hls = null;
          resolve({ status: 'failure' });
        }
      });
      hls.loadSource(url);
      hls.attachMedia(state.video);
    });
  }

  function attachBlobUrl(viewType, blobUrl) {
    const state = views[viewType];
    if (!state || !state.video) return;
    if (state.blobUrl) {
      URL.revokeObjectURL(state.blobUrl);
    }
    state.blobUrl = blobUrl;
    state.video.src = blobUrl;
  }

  function disposeView(viewType) {
    const state = views[viewType];
    if (!state) return;
    if (state.hls) {
      try { state.hls.destroy(); } catch (_) { /* ignore */ }
      state.hls = null;
    }
    if (state.blobUrl) {
      URL.revokeObjectURL(state.blobUrl);
      state.blobUrl = null;
    }
    if (state.video) {
      try { state.video.pause(); } catch (_) { /* ignore */ }
      state.video.removeAttribute('src');
      try { state.video.load(); } catch (_) { /* ignore */ }
    }
    delete views[viewType];
  }

  window.__divineHlsAuthLoaderFactory = createAuthLoaderFactory;
  window.__divineRegisterVideo = registerVideo;
  window.__divineAttachBlobUrl = attachBlobUrl;
  window.__divineFetchMp4 = fetchMp4;
  window.__divineLoadHls = loadHls;
  window.__divineDisposeView = disposeView;
})();
