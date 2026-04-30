# Brainstorm: Issue #3416 — Which disposal-fence shape closes the FlutterJNI-detach renderer crash?

Date: 2026-05-01

## Problem Statement

The investigation (#3416) identified the crash mechanism: ExoPlayer's MediaCodec
decoder produces in-flight frames into a Hybrid Composition–backed
`ImageReaderSurfaceProducer` after `FlutterJNI` has detached from native, and
the resulting `scheduleFrame()` call throws. The crash is inside Flutter SDK
code, but the trigger is on us — we let an Android `Surface` keep receiving
frames during/after teardown.

The mechanism is settled. The directional question is **what shape of fix to
ship**: the three-layer defense from the investigation, a single targeted
patch, a heavier synchronous fence, or a centralized guard at the
`MainActivity` level.

## Constraints

- **Layer boundaries** (`architecture.md`): the plugin is the Client layer.
  Disposal logic belongs inside the plugin — not in the app shell, not in
  Dart-side BLoCs, and not in Flutter SDK guards.
- **Plugin already has the right hooks**: `DivineVideoPlayerPlugin` already
  implements `ActivityAware`. The `onDetachedFromActivity` callback exists and
  is currently a no-op (line 78 of `DivineVideoPlayerPlugin.kt`). Wiring it
  up is the canonical Flutter pattern, not a new abstraction.
- **Hybrid Composition is non-negotiable**: video performance regresses
  meaningfully if we drop back to TextureView. Don't trade perf for safety.
- **The previous fix (#2795) was correct for what it covered** (navigation
  channel guard) — duplicating its style at the renderer level via reflection
  is fragile. Keep the safety logic on the app side of the Surface, not the
  Flutter side.
- **Media3's `setVideoSurface(null)` and `clearVideoSurface()` are async.**
  They post a message to the playback thread; they do not block. Any "wait
  until the decoder is fully flushed" approach is a dance with no clean API.
- **Per `MEMORY.md`**: skip git worktrees, work locally on a branch.

## Prior Art

- `MainActivity.kt` + `FlutterJNILifecycleGuard` (PR #2795) — guards the
  navigation `MethodChannel`. Different code path; coexists.
- `mobile/packages/divine_video_player/android/.../DivineVideoPlayerPlugin.kt`
  — the plugin already pauses players on `Activity.onPause` via a
  `DefaultLifecycleObserver`. The activity-detach callback is wired but
  empty.
- `mobile/packages/divine_video_player/android/.../DivineVideoPlayerInstance.kt:593-610`
  — `dispose()` already does the right things in the right order
  (`setVideoSurface(null)` → `release()` → texture release). The window
  exists because each step is async w.r.t. the decoder thread, not because
  the order is wrong.
- `mobile/packages/divine_video_player/android/.../DivineVideoPlayerViewFactory.kt:46-48`
  — `PlatformView.dispose()` only nulls `playerView.player`. This is the
  most exploitable window during normal navigation (per-feed-item dispose
  cycle in pooled-feed scrolling, no Activity destroy required).
- PR #3060 (`fix(divine_video_player): implement disposal of zombie players
  on hot-restart`) — pattern for adding disposal robustness without changing
  the public plugin API. Same shape as the proposed fix.
- No prior brainstorm on this issue.

## Approaches Explored

### Approach A — Three-layer disposal hardening (investigation's recommendation)

**Description.** Three coordinated changes:
1. `DivineVideoPlayerPlugin.onDetachedFromActivity()` calls
   `PlayerRegistry.forAll { it.stopForActivityDetach() }` — `stop()` +
   `setVideoSurface(null)` on every live instance, but does NOT release.
   The full release still happens in `onDetachedFromEngine`.
2. `DivineVideoPlayerPlatformView.dispose()` adds `player.setVideoSurface(null)`
   + `player.stop()` before nulling `playerView.player`.
3. `DivineVideoPlayerInstance.dispose()` swaps `setVideoSurface(null)` for
   the explicit `Player.clearVideoSurface()` Media3 API and adds an explicit
   `player.stop()` before `release()`.

**Layers affected:** Client (plugin native code only). No Dart-side changes.

**Pros:**
- Closes both known race windows: per-PlatformView dispose during normal
  navigation (the high-frequency case) and Activity-destroy without
  preceding `onPause` (the rare-but-real case).
- Each layer's change is small (≤5 lines per site) and reads as
  documentation — explicit `stop()` + `clearVideoSurface()` makes intent
  obvious to the next reader.
- Defense-in-depth: if any one layer regresses or a new code path adds a
  fourth dispose entry point, the other two layers still protect.
- Matches the existing pattern (`onAppBackgrounded`/`onAppForegrounded`
  + lifecycle observer) of attaching player-lifecycle behavior to plugin
  callbacks.

**Cons:**
- Largest diff of the four candidates. Three call-sites to test.
- "Belt and suspenders" can mask which layer actually closed the window
  in metrics — if the crash recurs after this fix, harder to bisect.

**Risks / Unknowns:**
- `Player.clearVideoSurface()` vs `setVideoSurface(null)` — they should be
  semantically identical in Media3 1.4+, but the explicit form is the
  documented "I want to ensure no more frames go to this surface" call.
  Media3 source confirms; low risk.
- `Player.stop()` then `release()` is the Media3 idiom; no risk.

**Complexity:** Low (it's three small native edits + tests).

### Approach B — Minimum: PlatformView.dispose hardening only

**Description.** Only change `DivineVideoPlayerViewFactory.kt:46-48`:
```kotlin
override fun dispose() {
    val player = playerView.player
    playerView.player = null
    player?.let {
        it.setVideoSurface(null)
        it.stop()
    }
}
```
Leave `onDetachedFromActivity` as a no-op; leave `Instance.dispose` unchanged.

**Layers affected:** Client (plugin) — single file.

**Pros:**
- Smallest possible diff (~5 lines).
- Closes the **most common** window — per-PlatformView dispose during
  normal pooled-feed scrolling. Each feed item's PlatformView disposes on
  scroll-out; without the change, every scroll-out is a candidate window
  for the race.
- Easy to reason about; one-test PR.

**Cons:**
- Does not address Activity teardown without `onPause`. The 1% case still
  exists, but Crashlytics says 31 events / 7 days — possibly within that
  1% (rapid back-press / app-finish paths).
- If the regression metric doesn't drop to ~zero after shipping B, we're
  back to investigating with one fewer candidate to bisect.

**Risks / Unknowns:**
- Could leave a residual crash rate. Hard to estimate without instrumentation.

**Complexity:** Very low.

### Approach C — Activity-detach handler only

**Description.** Only wire up `DivineVideoPlayerPlugin.onDetachedFromActivity`
to stop all players. Leave PlatformView dispose and Instance dispose
unchanged.

**Layers affected:** Client (plugin) — single method.

**Pros:**
- Smallest diff for the "Activity destroyed without onPause" case
  specifically.

**Cons:**
- **Does not address the high-frequency case** of PlatformView disposal
  during normal scrolling. Each pooled-feed item disposes its PlatformView
  when it scrolls offscreen — this happens many times per session,
  independent of any Activity teardown. Approach C leaves that window open.
- This is the inverse of B: solves the rare case while leaving the common
  case unfixed. Likely the worst metric outcome of the candidates.

**Risks / Unknowns:**
- Almost certainly insufficient on its own.

**Complexity:** Very low.

### Approach D — Synchronous frame fence in `Instance.dispose`

**Description.** After `setVideoSurface(null)`, wait for the decoder thread
to finish in-flight frames before releasing the surface. Media3 doesn't
expose a blocking "drain" call, so this would mean either:
- Posting to the playback thread and using `CountDownLatch` to await its
  completion, OR
- A short fixed delay (`Thread.sleep(50)`) — the kind of thing
  `code_style.md`'s "Avoid introducing arbitrary `Future.delayed()` calls"
  rule explicitly disallows on the Dart side, and the same instinct applies
  on Kotlin.

**Layers affected:** Client (plugin) — single method, but threading change.

**Pros:**
- Theoretically the most thorough fix — guarantees no in-flight frames
  survive past dispose.

**Cons:**
- Reaches into Media3 thread management; brittle to Media3 internals
  changing.
- Adds latency to the dispose path. On pooled-feed scroll, this is hot —
  every disposed item pays the fence cost.
- Does not help the Activity-teardown path (different entry point).
- Violates "no arbitrary delays" guidance — even a `CountDownLatch` is
  awkward when the underlying Media3 API doesn't expose a clean signal.

**Risks / Unknowns:**
- Performance regression on scroll dispose.
- Unknown if Media3 even guarantees the playback-thread message is processed
  before `release()` returns.

**Complexity:** Medium (threading) — and doing it properly is hard.

### Approach E — Centralize via MainActivity hook (defensive engine-detach guard)

**Description.** Add a `beforeEngineDetach` hook in `MainActivity` that
explicitly calls `PlayerRegistry.disposeAll()` (via a method channel or a
direct Kotlin reference) before the engine detaches.

**Layers affected:** App shell (`MainActivity.kt`) + cross-package coupling.

**Pros:**
- Centralizes "stop all media before detach" in one well-known place.
- Could be reused for future plugins with similar concerns.

**Cons:**
- **Layer violation** per `architecture.md`: the app shell shouldn't know
  about plugin internals. The plugin's `ActivityAware` lifecycle is the
  canonical Flutter mechanism for this; bypassing it duplicates the
  responsibility.
- Cross-package import coupling — `MainActivity` would need to know about
  `PlayerRegistry`.
- Doesn't address PlatformView dispose during scrolling (same blind spot
  as Approach C).
- The "centralized guard" pattern that worked for the navigation channel
  worked because `MethodChannel` is a generic Flutter primitive. The
  player registry is plugin-specific; centralizing it leaks abstraction.

**Risks / Unknowns:**
- Sets a precedent that other plugins might copy ("just add another hook
  in MainActivity for X"), eroding plugin encapsulation over time.

**Complexity:** Medium (cross-package wiring + future maintenance).

## Recommendation

**Approach A** — three-layer disposal hardening.

Three reasons:

1. **It closes both windows the investigation identified.** The
   PlatformView-dispose window during pooled-feed scrolling is the
   high-frequency case; the Activity-teardown-without-onPause window is
   the rare-but-real case. Approaches B, C, and E each cover only one of
   the two; D covers the wrong one with a brittler tool.

2. **All three layer-changes are small and read as intent.** Each site
   adds 1–3 lines (`stop()` + `clearVideoSurface()` / `setVideoSurface(null)`)
   that document "I am stopping the decoder now and detaching the surface."
   That's better than a comment explaining the implicit invariant.

3. **It stays inside the plugin.** No app-shell changes, no
   cross-package coupling, no Flutter-SDK reflection. Clean boundary,
   easy to test (Mockito-Kotlin verifications on call ordering), easy to
   roll back if telemetry shows a surprise.

If review pushes back on the diff size, the natural fallback is **Approach B**
(PlatformView dispose only) — it captures the high-frequency case and is the
single highest-leverage change. If Crashlytics still shows residual events
after B, layer in the Activity-detach hook (the third part of A) without
re-reviewing the PlatformView diff.

I would not ship D or E without a concrete failure of A first.

## Open Questions for /plan

- [ ] Is `Player.clearVideoSurface()` strictly preferable to
      `Player.setVideoSurface(null)` on Media3 1.4+? My read is yes, but
      worth a 30-second confirmation against the plugin's pinned Media3
      version before the diff.
- [ ] Do we need both `player.stop()` AND `player.clearVideoSurface()` in
      `Instance.dispose()`, or is one enough? Default for /plan: both, for
      defense-in-depth and explicit-intent.
- [ ] Should `stopForActivityDetach()` also pause audio overlays
      (`audioOverlayManager.pauseAll()`)? Probably yes for consistency
      with `onAppBackgrounded`, but doesn't affect the crash.
- [ ] Mockito-Kotlin is the project's verification idiom for Android tests
      — confirm that's the right tool vs adding a new mocking framework.

## Prerequisites

- [ ] None. The fix is purely native-Android and doesn't depend on
      design, protocol, or other PRs.

## Next Step

`/plan https://github.com/divinevideo/divine-mobile/issues/3416` with
Approach A as the chosen shape.
