# HLS + NIP-98 auth on Flutter web — spike design

Status: draft
Owner: @rabble
Date: 2026-04-17
Branch: spike/hls-auth-web-player

## Problem statement

Divine hosts videos on Blossom-style storage at `https://media.divine.video/<sha256>`. For age-gated or otherwise restricted content, the media server responds `HTTP 401 Unauthorized` to any request that does not carry an `Authorization: Nostr <base64 NIP-98 event>` header. On native (iOS, Android, macOS) the pooled media_kit-based player pipes request headers into its underlying HTTP client, and the viewer-auth retry flow (PR #3127) reclassifies `401` as `VideoErrorType.ageRestricted`, prompts the user, signs a NIP-98 event, and retries with the header attached. On Flutter web this path is architecturally broken: `WebVideoPlayer` delegates to `VideoPlayerController.networkUrl(url, httpHeaders: headers)` which — on the web platform — sets `videoElement.src = uri` on a plain HTML5 `<video>` element. HTML5 `<video>` ignores `httpHeaders` entirely for direct MP4, so the browser issues an unauthenticated GET, receives 401, and surfaces a generic `MEDIA_ERR_SRC_NOT_SUPPORTED`. The classifier in `pooled_video_player` that recognises the string "401" is not on the hot path for web, so even a raw 401 never becomes `ageRestricted`, the viewer-auth retry never fires, and the user sees the "Failed to load video" copy from `WebVideoPlayer`. PR #3107 only removes confirmed 404s and is intentionally silent about 401, which is why the preview deploy still shows auth-gated items stuck.

## Current state

Native (working): `PooledVideoFeed` → `media_kit` with a pooled controller → HTTP client honors `httpHeaders`. If the initial load errors with a 401 string, `VideoFeedController._classifyError` (`.../pooled_video_player/lib/src/controllers/video_feed_controller.dart:651`) maps it to `VideoErrorType.ageRestricted`. `playbackStatusFromError` in `video_playback_status_state.dart:99` lifts that to `PlaybackStatus.ageRestricted`. The feed shows an age-restricted overlay that triggers `retryAgeRestrictedPooledVideo` (`mobile/lib/screens/feed/pooled_age_restricted_retry.dart`), which calls `ref.read(mediaAuthInterceptorProvider).handleUnauthorizedMedia(...)`, gets back signed `Authorization` headers, and invokes `feedController.updateRequestHeadersAndRetry(index, headers)`. Native session-level NIP-98 signing lives in `mobile/lib/services/media_viewer_auth_service.dart` and is backed by `BlossomAuthService.createGetAuthHeader` / `Nip98AuthService.createAuthToken`.

Web (broken): `WebVideoFeed` → `WebVideoPlayer` (`mobile/lib/widgets/web_video_player.dart`) → `VideoPlayerController.networkUrl(url, httpHeaders: headers)` → the `video_player_web_hls` plugin (`~/.pub-cache/.../video_player_web_hls-1.3.0/lib/src/video_player.dart`). In that plugin's `initialize()`:
- For HLS manifests (`m3u8`), it constructs an hls.js instance with `HlsConfig(xhrSetup: ...)` and the Dart-side `headers` map is applied to each XHR via `xhr.setRequestHeader`. So if an HLS URL is used, Dart-provided headers *can* reach the network. However, `xhrSetup` is synchronous — it cannot await a Dart future that computes a fresh NIP-98 signature for each segment — and the current `WebVideoPlayer` never calls `MediaViewerAuthService` anyway, so even the HLS path carries no `Authorization`.
- For direct MP4 it sets `_videoElement.src = uri` (line 136) and drops `headers` on the floor. This is the exact path the production feed uses today (direct MP4 first), and it is the unrecoverable case: HTML5 `<video>` cannot carry custom headers, and the error surfaced via `MediaError.code = 4 (MEDIA_ERR_SRC_NOT_SUPPORTED)` does not contain the string "401".

Confirmed via `curl -sI` against the known auth-gated hash `a9bbbce1b03958553a5ee1546140d5d930b8a86c1fa967ea874fb5241bd5e41c`: every variant (`<hash>`, `<hash>.mp4`, `<hash>/hls/master.m3u8`, `<hash>.jpg`) returns HTTP/2 401 with `access-control-allow-origin: *` and `access-control-allow-headers: Authorization, Content-Type, X-Sha256`. CORS is already open for `Authorization`, so the constraint is purely "how do we attach the header from a Dart web build".

## Reference implementation (divine-web)

divine-web solved this by bypassing the platform video wrapper entirely and driving `hls.js` directly, using its MSE pipeline plus a custom loader. The load-bearing pieces are all short:

- `divine-web/src/lib/hlsAuthLoader.ts:14-51` — `createAuthLoader(getAuthHeader)` returns a class extending `Hls.DefaultConfig.loader`. Its `load(context, config, callbacks)` awaits `getAuthHeader(context.url, 'GET')`, stuffs the result into `context.headers['Authorization']`, then delegates to `super.load(...)` via `.finally(...)`. Because `load` is async-delegated (not `xhrSetup`-based), per-segment NIP-98 signing is fine. This is how the "different header per URL per segment" requirement is met.
- `divine-web/src/lib/nip98Auth.ts:19-36` — `createNip98AuthHeader(signer, url, method)` builds a kind-27235 event template via `NIP98.template(new Request(url, {method}))`, signs it, base64-encodes the JSON, returns `Nostr ${encoded}`.
- `divine-web/src/hooks/useAdultVerification.ts:8-111` — gates header generation on a `localStorage`-persisted verification flag (30 day TTL, key `adult-verification-confirmed`), broadcasts changes via a `storage`-style event, and exposes `getAuthHeader(url, method)` that returns `null` when the user is not verified or has no signer.
- `divine-web/src/components/VideoPlayer.tsx:687-889` — the effect that wires it up:
  - does a HEAD preflight via `checkMediaAuth(url)` (`useAdultVerification.ts:116-130`); if it returns 401/403 and the user is not yet verified, it flips `requiresAuth=true` and renders `AgeVerificationOverlay` instead of a `<video>` tag. Critical detail: the `poster` is withheld during `requiresAuth || authCheckPending` so the poster's 401 does not itself trip an error.
  - once `isAdultVerified` is true, it instantiates `new Hls({ ..., loader: createAuthLoader(getAuthHeader) })`, `hls.loadSource(hlsUrl)`, `hls.attachMedia(videoElement)`.
  - on `Hls.Events.ERROR` with `data.response.code in (401, 403)` it destroys the instance and re-flips `requiresAuth`, prompting re-verification.
  - for direct MP4 with auth, it does a `fetch(url, { headers: { Authorization } })`, builds a blob URL via `URL.createObjectURL(blob)`, assigns to `video.src`, and tracks the blob URL in a ref so it can `revokeObjectURL` on unmount. This works but loses Range/seek granularity and streams the whole file — acceptable because classic Vine content is ~6s / 2-4 MB.
- `divine-web/src/components/VideoCard.tsx:118-134` — direct MP4 first, HLS as fallback: `effectiveHlsUrl = hlsFallbackUrl || ((isClassicVine || isShortForm) ? undefined : ...)`. Short-form (≤60s) and classic Vine (migrated / timestamp < 2017-01-17) skip HLS entirely because the 2+ RTs for manifest+segment are slower than one MP4 GET for 6-second clips, and the transcoder distorts square aspect ratios.

## Options evaluated

### Option A — New Flutter package `packages/hls_auth_web_player`, JS interop to hls.js

Build a `kIsWeb`-only package that mirrors the `WebVideoPlayer` surface (init / play / pause / seekTo / setVolume / setLooping / dispose, plus an `onInitialized(controller)` for external access). Internally it uses `dart:js_interop` + `package:web` to instantiate `hls.js`, attach to a registered `HTMLVideoElement` platform view, and install a custom loader that calls back into Dart for per-URL `Authorization` headers. MP4 path uses `fetch`+blob-URL mirroring divine-web. The Dart `WebVideoPlayer` becomes a thin shim that picks between the legacy `video_player` controller factory and the new package based on a feature flag / host check.

Pros:
- Solves the actual problem. Per-segment NIP-98 signing is the whole reason we need a proper loader — `xhrSetup` cannot await Dart futures.
- Reuses `MediaViewerAuthService` as the single source of truth for signing. The Dart-JS boundary is an `async` callback: JS `(url, method) => jsPromise` backed by a Dart `Future<String?>`.
- Direct MP4 fallback + HLS retry parity with divine-web means we can share the same UX and tests.
- Keeps the change isolated to a new package; `WebVideoFeed` only needs a controller-factory swap.

Cons:
- New package surface to maintain. JS interop is inherently brittle to hls.js API shifts.
- Requires pinning `hls.js` in `web/index.html` (already present at `latest`, which we should change to a known-good version anyway).
- Tests need a fake hls.js shim.

### Option B — Fork / patch `video_player_web_hls` to expose a loader hook

Add an optional `loader`/`loaderFactory` parameter to `HlsConfig` in the pub package, plumb it through `xhrSetup`'s call site so Dart callers can pass a Dart-side loader. Upstream if accepted.

Pros:
- Smallest surface change in divine-mobile (`WebVideoPlayer` would pass a loader factory through `httpHeaders`-equivalent config).
- Benefits the wider Flutter ecosystem.

Cons:
- `video_player_web_hls` 1.3.0's `HlsConfig` only has `xhrSetup` (see `~/.pub-cache/.../video_player_web_hls-1.3.0/lib/hls.dart:33-38`). Exposing `loader` means a real API addition, not just a pass-through — the type has to model a JS class constructor from Dart, which is the same JS interop work as Option A without the benefit of owning the direct-MP4 path.
- Even with a loader hook, the direct-MP4 case is still `_videoElement.src = uri` in `video_player.dart:136` which ignores headers. So this option still doesn't fix MP4 — we would still need the blob-URL fetch dance somewhere.
- Upstream review and release are gated on external maintainers. Can't ship the fix behind a fork URL without adding a long-lived `git:` dependency.

### Option C — Cloudflare Worker proxy attaches auth server-side

Run a worker on an app-owned origin (e.g. `media-proxy.divine.video`). The web build requests `https://media-proxy.divine.video/<sha256>` with a short-lived app cookie or JWT; the worker validates and rewrites to a media.divine.video URL with a server-held NIP-98 identity or a signed presign.

Pros:
- Web player needs no hls.js integration; the HTML5 `<video>` element "just works".
- Could share the same presign pattern with non-browser clients.

Cons:
- Moves user-scoped signing to the server — the worker either needs the user's key (unacceptable) or a server-side identity that impersonates "the viewer", which breaks the NIP-98 semantic (the auth is meant to bind to a user event, not a relay-of-relays). This is a nostr protocol regression.
- Adds a new always-on piece of infra and a new auth story (cookie/JWT to the proxy).
- Doesn't match divine-web's approach, so web and mobile drift.
- Introduces a trusted intermediary for content delivery.

## Recommendation

**Option A.** Ship a new `packages/hls_auth_web_player` Flutter package with a JS interop wrapper around hls.js, a custom auth loader that calls back into Dart, a direct-MP4 `fetch`+blob fallback, and a controller-factory-shaped drop-in for `WebVideoPlayer`. This is the smallest change that correctly solves both the MP4 and HLS cases, preserves the user-bound NIP-98 semantic (each segment carries the current viewer's signed event), and keeps `MediaViewerAuthService` as the single signing authority. It matches the working reference implementation on divine-web function-for-function, so the UX, verification dialog, and age-restricted retry flow all have a known shape to reach parity with.

The fork-the-plugin path (Option B) buys less than it costs: the plugin's direct-MP4 path still ignores `httpHeaders`, so even after the upstream patch we would still have to write the blob-URL dance ourselves — at which point we might as well own the full web player. The proxy path (Option C) is incompatible with a per-user NIP-98 model.

## Design sketch

### File layout
```
mobile/packages/hls_auth_web_player/
  pubspec.yaml
  lib/
    hls_auth_web_player.dart               # barrel (public API)
    src/
      hls_auth_web_controller.dart         # Dart-facing controller, mirrors VideoPlayerController shape
      hls_auth_loader.dart                 # Dart wrapper that installs the JS auth loader
      js/
        hls_interop.dart                   # @JS bindings: Hls, HlsConfig, Loader, LoaderContext, Events
        media_interop.dart                 # HTMLVideoElement helpers, platform view registry
      blob_mp4_source.dart                 # fetch(url, Authorization) -> Blob -> objectURL lifecycle
  test/
    hls_auth_web_controller_test.dart
    hls_auth_loader_test.dart
  web/
    hls_auth_web_player_init.js            # Optional tiny shim exposing helpers; may not be needed

mobile/lib/widgets/
  web_video_player.dart                    # unchanged public API; factory switches on feature flag
  web_video_player_factories.dart          # NEW: exposes hlsAuthWebControllerFactory
```

### Interop surface

Minimum bindings (Dart side `@JS()` externs), enough to drive hls.js and install our loader:

```dart
@JS()
library hls_interop;

import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('Hls.isSupported')
external bool hlsIsSupported();

@JS('Hls')
extension type Hls._(JSObject _) implements JSObject {
  external factory Hls(HlsConfig config);
  external void loadSource(String url);
  external void attachMedia(web.HTMLVideoElement video);
  external void on(String event, JSFunction handler);
  external void destroy();
}

@JS()
@anonymous
extension type HlsConfig._(JSObject _) implements JSObject {
  external factory HlsConfig({
    bool? enableWorker,
    bool? lowLatencyMode,
    int? backBufferLength,
    int? maxBufferLength,
    int? startLevel,
    bool? capLevelToPlayerSize,
    JSAny? loader,          // constructor function returned by our Dart wrapper
  });
}

// Pulled out so we can subclass Hls.DefaultConfig.loader from Dart.
@JS('Hls.DefaultConfig')
external JSObject get hlsDefaultConfig;
```

The custom loader is installed by executing a tiny JS snippet once, at app bootstrap, that declares `window.__divineAuthLoader(getAuthHeader)` — it closes over the divine-web-style loader subclass (`class extends Hls.DefaultConfig.loader`). Dart passes a `Future<String?> Function(String url, String method)` that interop converts to a JS async function using `(url, method) => (() async => ...)().toJS` via `dart:js_interop`. The cleanest path is to ship the loader factory as JS (matching `hlsAuthLoader.ts` 1:1), and from Dart just call `window.__divineHlsAuthLoader(authCallback)` to get back the constructor, then hand it to `HlsConfig.loader`.

### Auth callback wiring

```
WebVideoFeed (Flutter, lib/)
  └─ hlsAuthWebControllerFactory(url, video) { ... }
       └─ HlsAuthWebController
            ├─ preflight: HEAD url
            │    └─ 401/403 + not verified -> emit onRequiresAuth
            ├─ request auth header:
            │    ref.read(mediaAuthInterceptorProvider)
            │       .handleUnauthorizedMedia(context, sha256, url, serverUrl)
            │    -> Map<String,String> headers
            ├─ MP4 path: blobMp4Source.load(url, authorization)
            │    └─ fetch -> blob -> URL.createObjectURL -> video.src
            └─ HLS path: new Hls({ loader: window.__divineHlsAuthLoader(authCb) })
                  authCb(url, method) is a JS function backed by
                  MediaViewerAuthService.createAuthHeaders(
                    sha256Hash: sha256FromUrl(url),
                    url: url,
                    serverUrl: originOf(url),
                  ) -> Authorization
```

The age-verification dialog (existing `MediaAuthInterceptor`) is called once per feed session; the returned `Authorization` header is cached at the controller level (not persisted). Re-entry to a cold feed re-prompts via the existing dialog flow. We do NOT introduce the divine-web `localStorage` 30-day cache in this spike — the mobile app uses the in-process `AgeVerificationService` and `MediaAuthInterceptor` already, and the `shouldAutoShowAdultContent` path in `mobile/lib/services/media_auth_interceptor.dart:47` gives the same "verify once per session/preference" behaviour. Keeping a single verification store avoids a mobile/web drift.

### Fallback order (web only)

1. Direct MP4 with `Authorization` via `fetch`+blob (mirrors `VideoPlayer.tsx:812-868`), because classic Vine content is ~6s / 2-4MB and one GET beats manifest+segment.
2. HLS via hls.js + custom loader for anything longer-form or when MP4 returns a non-401 error (e.g. 404 against the raw blob but the transcoded master.m3u8 exists — mirrors `hlsFallbackUrl` in `VideoCard.tsx:131-134`).
3. On HLS fatal error: surface `PlaybackStatus.generic`; feed skips.

The bandwidth-aware URL selection from divine-web (`getOptimalVideoUrl`) is out of scope for this spike.

### Preserving existing native flow

No behavioral change for native. The native `pooled_video_player` 401-classifier + `retryAgeRestrictedPooledVideo` flow remains the source of truth for iOS/Android/macOS. The new package is web-only and is selected inside `WebVideoPlayer` by a factory switch. `MediaAuthInterceptor` and `MediaViewerAuthService` are reused unchanged.

### Hooking age-restricted state into the existing cubit

On web, when the preflight HEAD returns 401 or the hls.js `ERROR` event has `data.response.code == 401`, the controller emits a `HlsAuthWebEvent.requiresAuth` that the feed translates into `VideoPlaybackStatusCubit.report(video.id, PlaybackStatus.ageRestricted)`. The existing `AgeRestrictedOverlay` / verification retry UI then applies. This keeps one UI path instead of inventing a web-only verification flow.

## Open questions

1. **hls.js version pin.** `mobile/web/index.html:157` currently loads `hls.js@latest` via jsDelivr. For the loader subclass to keep working we should pin a known-good version (e.g. 1.5.x) and ship it as an asset or subresource-integrity-verified CDN URL. Decide: self-host in `web/` vs pinned jsDelivr tag.
2. **Per-segment signing cost.** Each HLS segment load triggers a NIP-98 sign. Amber/nsec.app-style remote signers have user-visible latency per sign. For in-app signing (local key) this is sub-ms; for remote signers it could be seconds per segment. Open question: should we cache a single per-URL-prefix header for the manifest's segment lifetime? divine-web does NOT cache and it works, but signers are browser-local there.
3. **Poster 401 poisoning.** Thumbnails at `<hash>.jpg` also 401. Need to confirm `VineCachedImage` / blurhash placeholder shows on web without hitting poster URL before auth; the divine-web workaround is "withhold `poster=` during `requiresAuth || authCheckPending`".
4. **Range header forwarding.** The custom loader needs to preserve hls.js's `context.rangeStart`/`rangeEnd` — it should, because we just append `Authorization` to `context.headers` and delegate to `super.load`. Verify with a manifest that includes byte-range segments.
5. **CSP.** If we self-host hls.js, confirm the existing CSP permits inline JS for the loader factory shim. Alternatively, ship the shim as a separate file rather than an inline `<script>`.
6. **Serving MP4 as blob breaks native `<video>` controls seeking on large files.** Fine for 6s Vines; will need proper HLS for anything over ~20MB. Document the cutoff where Option A's MP4 blob path becomes unsuitable.

## Test strategy

Unit tests (`packages/hls_auth_web_player/test/`):

- `HlsAuthWebController` with a fake auth callback and a fake `web.HTMLVideoElement`. Assert: preflight 401 emits `requiresAuth`; preflight 200 proceeds to load; auth-provided header is what the loader sees.
- `blob_mp4_source` with a faked `fetch`: 200 → objectURL assigned + revoked on dispose; 401 → `requiresAuth`; non-OK → `generic` error.
- Loader wrapper: inject a mock hls.js double (just a constructor that records the `loader` field); assert the configured loader invokes the Dart auth callback with each URL.

Widget tests (`mobile/test/widgets/`):

- `WebVideoFeed` with a stubbed controller factory: when the stub reports `requiresAuth`, the feed reports `PlaybackStatus.ageRestricted` to `VideoPlaybackStatusCubit` and the existing age-restricted overlay renders.
- Factory switch: with the feature flag off, `WebVideoPlayer` still calls the legacy `VideoPlayerController.networkUrl` factory.

Integration (`mobile/integration_test/`):

- `flutter drive -d chrome` against a test origin that mirrors `media.divine.video`'s 401 behaviour (a local `dhttpd` serving 401 JSON for unauth, 200 for `Authorization: Nostr *`). Asserts: feed item transitions from "auth required" to "playing" after a simulated age-verification tap.

Fake hls.js for tests: the cleanest pattern is a Dart-side `HlsFactory` that returns either the real `new Hls(cfg)` (production) or a `FakeHls` that exposes `loadSource`, `attachMedia`, `on`, `destroy` as recording spies. Widget tests inject the fake via Provider/Riverpod override, avoiding any real JS interop in unit tests.

## Scope / out-of-scope

In scope:
- New `packages/hls_auth_web_player` package.
- `WebVideoPlayer` factory switch behind `kIsWeb` + a feature flag (default on for staging, off for prod until QA passes).
- Integration with existing `MediaAuthInterceptor`, `AgeVerificationService`, `MediaViewerAuthService`, `VideoPlaybackStatusCubit`.
- hls.js version pin in `web/index.html`.
- Unit + widget tests for the new package and the factory switch.

Out of scope (not this PR, explicitly):
- Anything PR #3107 owns (skipping confirmed 404s). We are strictly about 401.
- The bandwidth-aware URL selection (`getOptimalVideoUrl`) — port later if needed.
- The localStorage 30-day verification cache — keep in-process mobile verification as the only store.
- Poster 401 handling fixes outside the feed (profile grids, categories strip) — follow-up.
- Native player changes (no changes to `pooled_video_player`, `media_kit`, or PR #3127's flow).

## Rollout

- Ship behind a `FeatureFlag.hlsAuthWebPlayer` default-off in prod, default-on in staging. The flag is web-only (`kIsWeb`-gated at the factory).
- Deploy to `preview.divine.video` first. Smoke test against the known auth-gated hash `a9bbbce1b...`.
- Success metric: the existing `VideoPlaybackStatusCubit` status distribution (ageRestricted dialog shown, then ready) surfaces in app logs. Rollback signal: a rise in `PlaybackStatus.generic` events tagged with the web factory, or a rise in `Failed to generate auth header` logs from the loader wrapper.
- Once staging is green and at least one full feed scroll on the preview deploy succeeds on a previously-401 video, flip the flag on in prod. Keep the flag for one release before deleting the legacy path.
- Rollback is a single remote-config flip back to the legacy `VideoPlayerController.networkUrl` factory. No schema or persisted-state migration.
