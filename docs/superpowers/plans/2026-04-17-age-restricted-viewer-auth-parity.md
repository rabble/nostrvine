# Age-Restricted Viewer Auth Parity Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Divine mobile pooled playback unlock `AgeRestricted` Blossom media by sending accepted viewer auth and retrying playback after age verification.

**Architecture:** `divine-blossom` already accepts either Blossom/BUD-01 `kind 24242` list auth or NIP-98 `kind 27235` HTTP auth for viewer media GET requests. The missing work is in `divine-mobile`: centralize viewer-auth header creation for media requests, teach pooled playback to open authenticated sources, and wire the `401` age-verification retry path to regenerate headers and retry the active player instead of only updating UI state.

**Tech Stack:** Flutter, Riverpod, `video_player`, `media_kit`, pooled_video_player package, Blossom/BUD-01 auth, NIP-98 auth

---

## File Map

- Modify: `mobile/lib/services/blossom_auth_service.dart`
  Purpose: existing BUD-01 GET auth generation for Blossom blobs.
- Modify: `mobile/lib/services/nip98_auth_service.dart`
  Purpose: existing NIP-98 HTTP auth generation for backend-style GET requests.
- Create: `mobile/lib/services/media_viewer_auth_service.dart`
  Purpose: single service that chooses accepted viewer auth for media playback requests and returns request headers for a specific media URL/hash.
- Modify: `mobile/lib/providers/app_providers.dart`
  Purpose: register the new viewer-auth service and stop duplicating protocol selection logic in widgets.
- Modify: `mobile/lib/providers/individual_video_providers.dart`
  Purpose: migrate legacy/non-pooled playback to the shared viewer-auth service so both playback stacks follow the same contract.
- Modify: `mobile/lib/services/media_auth_interceptor.dart`
  Purpose: replace direct Blossom-only header creation with shared viewer-auth creation.
- Modify: `mobile/packages/pooled_video_player/lib/src/models/video_item.dart`
  Purpose: carry optional per-source request headers or an auth descriptor into pooled playback.
- Modify: `mobile/packages/pooled_video_player/lib/src/controllers/video_feed_controller.dart`
  Purpose: open pooled player sources with headers, classify `401`, and retry the current source after auth is refreshed.
- Modify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
  Purpose: on Verify Age, invoke the real auth+retry flow instead of only resetting UI status.
- Modify: `mobile/lib/screens/feed/feed_video_overlay.dart`
  Purpose: same fix for the non-fullscreen pooled overlay path.
- Modify: `mobile/lib/widgets/video_feed_item/pooled_video_error_overlay.dart`
  Purpose: expose the pooled retry/auth affordance clearly once the retry path is real.
- Test: `mobile/test/services/media_viewer_auth_service_test.dart`
  Purpose: protocol-selection and header-generation coverage.
- Test: `mobile/test/services/media_auth_interceptor_test.dart`
  Purpose: verify age-check + auth-header generation behavior.
- Test: `mobile/packages/pooled_video_player/test/controllers/video_feed_controller_test.dart`
  Purpose: verify pooled playback opens sources with auth headers and retries after `401`.
- Test: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
  Purpose: verify Verify Age triggers auth generation and retry for pooled fullscreen playback.

## Chunk 1: Shared Viewer Auth Contract

### Task 1: Lock the server contract into a client-facing service

**Files:**
- Create: `mobile/lib/services/media_viewer_auth_service.dart`
- Modify: `mobile/lib/providers/app_providers.dart`
- Test: `mobile/test/services/media_viewer_auth_service_test.dart`

- [ ] **Step 1: Write the failing service tests**

Add tests that prove:
- when a SHA-256 blob hash is known, the service prefers Blossom/BUD-01 and returns `Authorization: Nostr ...`
- when no hash is available but a full media URL is available, the service can return NIP-98 auth for `GET <url>`
- when the user is unauthenticated, the service returns `null`
- the service never returns both protocols at once for one request

- [ ] **Step 2: Run the focused test file and verify it fails**

Run: `cd /Users/rabble/code/divine/divine-mobile/mobile && flutter test test/services/media_viewer_auth_service_test.dart`

Expected: FAIL because `MediaViewerAuthService` does not exist yet.

- [ ] **Step 3: Implement `MediaViewerAuthService`**

Implement a focused service that:
- accepts `sha256Hash`, `url`, `method`
- uses `BlossomAuthService.createGetAuthHeader(...)` when a blob hash is known
- falls back to `Nip98AuthService.createAuthToken(url: ..., method: HttpMethod.get)` when hash-based Blossom auth is not possible
- returns `Map<String, String>?` shaped exactly for playback callers, e.g. `{'Authorization': ...}`

Do not add age-verification UI logic here. This service only chooses and creates viewer identity proof for media GET requests.

- [ ] **Step 4: Register the new provider**

Add a provider in `app_providers.dart` that composes:
- `authServiceProvider`
- `blossomAuthServiceProvider`
- `nip98AuthServiceProvider`

- [ ] **Step 5: Re-run the service tests**

Run: `cd /Users/rabble/code/divine/divine-mobile/mobile && flutter test test/services/media_viewer_auth_service_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile
git add mobile/lib/services/media_viewer_auth_service.dart mobile/lib/providers/app_providers.dart mobile/test/services/media_viewer_auth_service_test.dart
git commit -m "feat(mobile): add shared viewer media auth service"
```

## Chunk 2: Unify Existing Auth Callers

### Task 2: Move legacy playback and interceptor code onto the shared service

**Files:**
- Modify: `mobile/lib/providers/individual_video_providers.dart`
- Modify: `mobile/lib/services/media_auth_interceptor.dart`
- Test: `mobile/test/services/media_auth_interceptor_test.dart`

- [ ] **Step 1: Write failing interceptor tests**

Add tests that prove:
- `handleUnauthorizedMedia(...)` verifies age access and returns viewer auth headers from the new service
- it prefers hash-based Blossom auth when the blob hash is known
- it returns `null` when verification is denied

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `cd /Users/rabble/code/divine/divine-mobile/mobile && flutter test test/services/media_auth_interceptor_test.dart`

Expected: FAIL because the interceptor still depends on `BlossomAuthService` directly.

- [ ] **Step 3: Replace direct Blossom auth calls in `MediaAuthInterceptor`**

Refactor `MediaAuthInterceptor` so it depends on `MediaViewerAuthService`, not `BlossomAuthService`. Keep the existing age-verification behavior unchanged.

- [ ] **Step 4: Migrate legacy controller header generation**

Update `individual_video_providers.dart` so:
- `_computeAuthHeadersSync`
- `_generateAuthHeadersAsync`
- `_cacheVideoWithAuth`

all call the shared viewer-auth service instead of duplicating Blossom-only request construction.

The legacy path must keep working exactly as before for hash-based Blossom URLs while gaining NIP-98 fallback if only the final URL is available.

- [ ] **Step 5: Re-run focused tests**

Run:
- `cd /Users/rabble/code/divine/divine-mobile/mobile && flutter test test/services/media_auth_interceptor_test.dart`
- `cd /Users/rabble/code/divine/divine-mobile/mobile && flutter test test/providers/individual_video_providers_test.dart`

Expected: PASS. If the second file does not exist, add focused coverage near the existing provider tests before proceeding.

- [ ] **Step 6: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile
git add mobile/lib/providers/individual_video_providers.dart mobile/lib/services/media_auth_interceptor.dart mobile/test/services/media_auth_interceptor_test.dart
git commit -m "refactor(mobile): share viewer auth across legacy media playback"
```

## Chunk 3: Make Pooled Playback Auth-Capable

### Task 3: Add per-source auth headers to the pooled player package

**Files:**
- Modify: `mobile/packages/pooled_video_player/lib/src/models/video_item.dart`
- Modify: `mobile/packages/pooled_video_player/lib/src/controllers/video_feed_controller.dart`
- Test: `mobile/packages/pooled_video_player/test/controllers/video_feed_controller_test.dart`

- [ ] **Step 1: Write failing pooled controller tests**

Add tests that prove:
- a pooled `VideoItem` can carry request headers for media open
- `VideoFeedController` passes those headers into `player.open(...)`
- a `401` classified as `ageRestricted` can be retried after the item’s headers are refreshed

- [ ] **Step 2: Run the pooled controller tests and verify they fail**

Run: `cd /Users/rabble/code/divine/divine-mobile/mobile/packages/pooled_video_player && flutter test test/controllers/video_feed_controller_test.dart`

Expected: FAIL because `VideoItem` has only a URL and the controller currently calls `player.open(Media(source), play: false)` with no header support.

- [ ] **Step 3: Extend the pooled playback source model**

Add a minimal, explicit representation for an authenticated source. Either:
- extend `VideoItem` with optional `requestHeaders`, or
- introduce a small `PlaybackSource` model and use it inside the controller.

Keep the public API narrow: a video may have a URL plus optional headers for that URL.

- [ ] **Step 4: Teach `VideoFeedController` to open authenticated media**

Update `_openWithFallbacks(...)` so it opens `Media(...)` with request headers when present.

Before writing code, verify the exact `media_kit` `Media` constructor API used by the current pinned package version and use the supported header field name. Do not invent a parameter.

- [ ] **Step 5: Add a public retry/update hook**

Expose the smallest controller API needed for the app layer to:
- replace the current video’s headers after age verification
- retry loading the current index without requiring a full screen rebuild

Keep the API at the controller boundary, not in widgets.

- [ ] **Step 6: Re-run pooled controller tests**

Run: `cd /Users/rabble/code/divine/divine-mobile/mobile/packages/pooled_video_player && flutter test test/controllers/video_feed_controller_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile
git add mobile/packages/pooled_video_player/lib/src/models/video_item.dart mobile/packages/pooled_video_player/lib/src/controllers/video_feed_controller.dart mobile/packages/pooled_video_player/test/controllers/video_feed_controller_test.dart
git commit -m "feat(pooled): support authenticated media sources"
```

## Chunk 4: Wire Verify Age into Real Pooled Retry

### Task 4: Make pooled fullscreen/feed retry with auth instead of only changing UI state

**Files:**
- Modify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
- Modify: `mobile/lib/screens/feed/feed_video_overlay.dart`
- Modify: `mobile/lib/widgets/video_feed_item/pooled_video_error_overlay.dart`
- Test: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

- [ ] **Step 1: Write failing UI flow tests**

Add tests that prove:
- when pooled playback reports `PlaybackStatus.ageRestricted`, tapping Verify Age triggers the auth flow
- successful verification updates the active pooled item with viewer auth headers
- the active item is retried after auth refresh
- failed verification does not retry

- [ ] **Step 2: Run the focused fullscreen/feed tests and verify they fail**

Run: `cd /Users/rabble/code/divine/divine-mobile/mobile && flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

Expected: FAIL because `_verifyAgeForVideo` and `_verifyAge` only call `verifyAdultContentAccess(...)` and reset playback status.

- [ ] **Step 3: Replace the fake pooled retry path**

Refactor:
- `pooled_fullscreen_video_feed_screen.dart::_verifyAgeForVideo`
- `feed_video_overlay.dart::_verifyAge`

so they:
- resolve the active media URL/hash
- ask `MediaViewerAuthService` or `MediaAuthInterceptor` for viewer auth headers
- update the active pooled controller item
- call the new controller retry hook

Do not leave “set playback status to ready” as the only effect.

- [ ] **Step 4: Keep the pooled error overlay behavior aligned**

Ensure `PooledVideoErrorOverlay` still shows age-restricted messaging, but the retry action now reflects the actual pooled retry flow. If Verify Age remains a separate overlay action, keep the button labeling and state transitions consistent.

- [ ] **Step 5: Re-run focused tests**

Run: `cd /Users/rabble/code/divine/divine-mobile/mobile && flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile
git add mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart mobile/lib/screens/feed/feed_video_overlay.dart mobile/lib/widgets/video_feed_item/pooled_video_error_overlay.dart mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart
git commit -m "fix(feed): retry pooled age-gated playback with viewer auth"
```

## Chunk 5: End-to-End Verification and Contract Update

### Task 5: Verify both stacks and document the contract

**Files:**
- Modify: `mobile/docs/superpowers/specs/2026-04-05-moderated-content-filter-design.md` (or the nearest current spec documenting pooled age-gated behavior)
- Optionally modify: `mobile/docs/PRODUCTION_CHECKLIST.md`

- [ ] **Step 1: Add or update docs**

Document the protocol split explicitly:
- Blossom/BUD-01 and NIP-98 are both accepted by `divine-blossom` for viewer media GET requests
- mobile legacy and pooled playback now share a single viewer-auth policy
- backend API auth remains NIP-98; upload/delete management remains Blossom auth where required

- [ ] **Step 2: Run focused package/app tests**

Run:
- `cd /Users/rabble/code/divine/divine-mobile/mobile/packages/pooled_video_player && flutter test test/controllers/video_feed_controller_test.dart`
- `cd /Users/rabble/code/divine/divine-mobile/mobile && flutter test test/services/media_viewer_auth_service_test.dart`
- `cd /Users/rabble/code/divine/divine-mobile/mobile && flutter test test/services/media_auth_interceptor_test.dart`
- `cd /Users/rabble/code/divine/divine-mobile/mobile && flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

Expected: PASS.

- [ ] **Step 3: Run targeted static analysis**

Run:
- `cd /Users/rabble/code/divine/divine-mobile/mobile && flutter analyze lib/services lib/screens/feed lib/providers`
- `cd /Users/rabble/code/divine/divine-mobile/mobile/packages/pooled_video_player && flutter analyze lib`

Expected: PASS or only pre-existing warnings unrelated to this change.

- [ ] **Step 4: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile
git add mobile/docs/superpowers/specs/2026-04-05-moderated-content-filter-design.md mobile/docs/PRODUCTION_CHECKLIST.md
git commit -m "docs(mobile): record viewer auth contract for age-gated playback"
```

