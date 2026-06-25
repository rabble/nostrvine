# Swipe-to-Tune Feed Recommendations — Design

**Date:** 2026-06-25
**Status:** Design proposal — mobile implementation tracked by #5517
**Scope:** `divine-mobile` client only

---

## Summary

Users can directly tune their own recommendation feed from the fullscreen
video player:

- **Swipe right** = more like this.
- **Swipe left** = less like this.

A committed horizontal swipe publishes a small Nostr feedback event and
advances the feed immediately. The event is public, append-only, and shaped so
a later funnelcake/Gorse change can consume it as recommendation feedback:
`user`, `item`, `direction`, `timestamp`, plus optional creator/topic
generalization tags.

This is **feed-shaping, not a social reaction**. A NIP-25 reaction is a public
statement about content. A tuning swipe is a personal instruction to the user's
own algorithm. The two stay separate: a user can like a video without wanting
more of it, or want more like it without publicly liking it.

### In Scope vs Deferred

| In scope in this mobile spec | Deferred to later work |
|---|---|
| Horizontal gesture, thresholding, indicator animation, haptics | Funnelcake ingestion from relay |
| Publishing the feed-tuning event | Gorse feedback mapping/reranking |
| New `feed_tuning_repository` package | Relay kind allow-listing/deploy |
| `FullscreenFeedBloc` tuning event + page-advance wiring | Reserving/registering the final kind number |
| Undo affordance for accidental swipes | Interests/profile sync or user-facing preference list |
| L10n, accessibility, tests | Cross-device display of past tuning actions |

The mobile work should be useful before backend ingestion lands: swipes feel
real, publish successfully once the relay accepts the kind, and leave a clear
event stream for backend implementation.

---

## Decisions

1. **Mobile end-to-end first.** Ship gesture and event publishing now. Backend
   ingestion is a separate spec. The event contract below is the interface.

2. **A swipe is not a Like.** Do not reuse NIP-25 kind 7. Likes remain social;
   swipes are recommendation feedback.

3. **Public plaintext event.** "Personal" means "shapes my feed", not
   "secret". We considered NIP-44 encryption-to-self and encryption to a
   service pubkey, but plaintext is the chosen v1 because funnelcake can ingest
   it directly from relay storage. Users should assume tuning signals are
   public.

4. **Append-only, latest-wins.** Each swipe creates one immutable feedback
   event. Gorse can interpret the newest event for `(user, target)` as the
   current intent. Correcting your mind means swiping again; accidental swipes
   can additionally be retracted with NIP-09.

5. **Dedicated Divine feed-tuning kind, not NIP-32 kind 1985.** NIP-32 labels
   were rejected because moderation tooling scans kind 1985. A high-volume
   stream of "less" labels on creators could be misread by naive or hostile
   tooling as distributed downranking/moderation. We use a use-case-specific
   kind and only borrow normal targeting tags (`a`, `e`, `p`, `t`).

6. **Both directions dismiss and advance.** Training rhythm matters. Even
   "more like this" advances to the next video instead of lingering.

7. **Keep creator/topic generalization on both directions.** `p` and `t` tags
   appear on both `more` and `less` events so the backend can learn at item,
   creator, and topic levels. This is deliberately not a block/mute signal.

8. **Advance by paging, never by removing.** A committed swipe pages the feed
   forward on the existing scroll/page controller (the same one
   `FullscreenFeedIndexChanged` already tracks). The swiped video stays in the
   list — it is not added to `removedVideoIds` and does not touch the
   deletion/block/mute removal path (`_onRemoveVideo` /
   `FullscreenFeedStatus.emptyAfterRemoval`, see `fullscreen_feed_bloc.dart:481`).
   Undo is just "page back". This avoids a whole second dismissal/restore
   subsystem.

---

## Event Contract

Use a new **regular append-only Nostr kind** owned by Divine.

```jsonc
{
  "kind": 4242, // EventKind.feedTuning, regular range 1000-9999
  "content": "",
  "tags": [
    ["direction", "more"],                              // "more" | "less"
    ["a", "34236:<authorPubkey>:<dTag>", "<relayHint>"],// stable video coordinate
    ["e", "<videoEventId>", "<relayHint>"],             // concrete event version
    ["p", "<authorPubkey>"],                            // creator generalization
    ["t", "<hashtag>"],                                 // 0..n topic tags
    ["k", "34236"]                                      // target event kind
  ]
}
```

### Contract Rules

- **Kind range:** the kind must be in the regular range (`1000-9999`), not the
  parameterized-replaceable range (`30000-39999`), because every swipe is an
  append-only event and must not require a `d` tag.
- **Direction:** exactly one `["direction", "more"|"less"]` tag. One kind,
  two directions.
- **`e` is the authoritative item key, always present.** It identifies the
  concrete video event and is always reliable. Backend ingestion keys the Gorse
  item on `e`.
- **`a` is best-effort enrichment.** Include it only when the video has a *real*
  `d` tag. The model is not safe to read blindly here: `VideoEvent.vineId` /
  `stableId` fall back to the event id when there is no `d` tag
  (`video_event.dart:558`), so `34236:<pubkey>:<vineId>` can be a fabricated
  coordinate. Emitting `a` requires a real-d-tag accessor on the model (add a
  `dTag` / `hasDTag` getter); if it's absent, omit `a` and ship `e`-only. No
  invariant reporting — an `e`-only event is valid, not an error.
- **Relay hint:** prefer `video.sourceRelay`; otherwise use the canonical
  Divine relay hint. Do not emit an empty third tag value.
- **Creator/topic tags:** include `p` for `video.pubkey` and one `t` per
  `video.hashtags` entry, normalized the same way video publishing/parsing
  already does. If there are no hashtags, emit no `t` tags.
- **Target kind:** include `["k", "34236"]` in v1. It is cheap for backend
  filtering and mirrors NIP-09 deletion examples already used in repository
  tests.
- **Undo:** publish a NIP-09 kind-5 deletion request referencing the
  feed-tuning event id with an `e` tag and `["k", "4242"]`.
  Re-swiping remains latest-wins; deletion is for accidental immediate undo.

### Open Rollout Dependency

Mobile pins `EventKind.feedTuning = 4242` as the Divine client/backend contract.
Before enabling the feature flag in production, funnelcake ingestion and the
relay allow-list must use that same kind.

---

## Mobile Architecture

Follow the repo's layered flow: **UI -> BLoC -> Repository -> Client**.

### Repository Layer: `feed_tuning_repository`

Create `mobile/packages/feed_tuning_repository` as a Flutter workspace package
with no UI dependencies.

Responsibilities:

- Construct and publish feed-tuning events.
- Own the kind number, tag names, direction enum, and target derivation.
- Publish NIP-09 deletion events for Undo.
- Hide signer/client details from UI and BLoC code.

Public API shape:

```dart
enum FeedTuningDirection { more, less }

abstract interface class FeedTuningRepository {
  /// Publishes a feed-tuning signal for [video]. Fire-and-forget.
  /// Returns the published event id (known synchronously at signing time),
  /// or null when there is no signer and nothing was attempted.
  Future<String?> tune({
    required VideoEvent video,
    required FeedTuningDirection direction,
  });

  /// Retracts a prior signal via a NIP-09 (kind-5) deletion.
  Future<void> undo(String feedTuningEventId);
}
```

Implementation notes:

- Prefer one `tune(...)` method plus convenience wrappers only if call sites
  read better.
- Constructor-inject the Nostr client/signing abstraction used by existing
  publish repositories.
- Follow the `dm_repository` reporter-port pattern:
  network/relay publish failures are not Crashlytics-worthy; programming
  invariants and unexpected malformed target derivation are.
- Tests should use the existing mocktail style in package tests.
- Expose constants from the package and cross-reference the shared EventKind
  constant. Do not scatter numeric kinds or tag strings across app code.

### BLoC Layer: `FullscreenFeedBloc`

The BLoC publishes the signal; it does **not** mutate the video list (advancing
is paging — see Decision 8).

- Add `FullscreenFeedTuningSwipeCommitted(videoId, direction)`.
- Inject `FeedTuningRepository`.
- Resolve the active `VideoEvent` from state by `videoId` at commit time, so a
  stale UI-captured object isn't published after pagination/reorder.
- Call `feedTuningRepository.tune(...)` and keep the returned event id in a
  short-lived `lastTuningAction` outbox value in state for the UI's snackbar.
  Clear it once consumed so a rebuild doesn't re-show the snackbar.
- The video list is untouched: no `removedVideoIds`, no `_onRemoveVideo`, no
  `emptyAfterRemoval`. The UI pages forward on commit and pages back on Undo.
- On Undo, call `undo(eventId)` (the id is always available when a publish was
  attempted; a null id means nothing to retract).
- No error strings in state — status enum + `addError` only.

### Dependency Wiring

Wire the repository at the fullscreen feed route boundary:

- Add a Riverpod provider for `FeedTuningRepository`.
- If the provider can change identity on auth/signing changes, wrap
  `BlocProvider` with a `ValueKey((feedRepository, feedTuningRepository, ...))`
  per `docs/STATE_MANAGEMENT.md`.
- Gate bloc creation if signer/client dependencies are not ready. Do not create
  a bloc that captures a null signer and silently stays unable to publish after
  auth flips.

### Presentation Layer

Add a small gesture wrapper around the active fullscreen feed item/feed stack.
Keep it as widget classes, not `Widget _buildX()` helpers.

Gesture behavior:

- Track horizontal drag only after angle and distance thresholds clearly beat
  vertical paging.
- Below threshold: snap back and publish nothing.
- At threshold crossing: fire one haptic tick and lock the indicator.
- Release past threshold: dispatch tuning commit to the BLoC.
- Release before threshold or cancel: reset visual state.

Visual feedback:

- Right swipe: warmer/brighter "more" indicator.
- Left swipe: cooler/dimmer "less" indicator.
- Edge-anchored icon + localized label fades/scales with drag progress.
- The video translates with the finger and tilts subtly; keep movement bounded
  so text/action overlays remain readable during partial drags.
- Use `VineTheme`/`divine_ui` tokens only. Choose exact colors/icons during
  implementation and contrast-check them.

Discoverability:

- One-time coach mark on the first eligible feed session: faint left/right
  chevrons with short localized copy.
- Dismiss on first committed tuning swipe or explicit close.
- Persist the dismissal locally. Do not add permanent chrome.

Accessibility:

- Provide explicit semantic actions or buttons for "More like this" and "Less
  like this" so non-drag users can tune the feed.
- Announce committed actions with `SemanticsService.sendAnnouncement(...)`.
- All copy goes through `context.l10n`; update ARB files and generated l10n.

Undo:

- Show a floating snackbar after commit with localized text and an Undo action.
- The snackbar reads the BLoC outbox; it does not await the repository from UI.
- Undo pages back to the swiped video and dispatches the undo event. The event id
  is known synchronously at publish time, so there is no "id arrives later" race
  to handle.

---

## Implementation Sequence

1. **Protocol prep:** pin the mobile/backend kind constant and confirm the relay
   allow-list path before enabling the feature flag.
2. **Repository package:** build event construction, publish, undo, reporter
   sites, package tests.
3. **BLoC wiring:** add the tuning event + `lastTuningAction` outbox and bloc
   tests (publish + no list mutation), without touching gesture UI yet.
4. **Gesture spike:** add the wrapper behind a local feature flag or test-only
   switch, tune thresholds on device, and verify vertical paging still wins.
5. **Full UI:** indicators, haptics, coach mark, snackbar, l10n, accessibility.
6. **Verification pass:** affected package tests, fullscreen feed bloc/widget
   tests, l10n consistency, `flutter analyze`, and goldens only if visual
   baselines change.

---

## Risks and Mitigations

1. **Gesture conflict with vertical paging.** Highest risk. The fullscreen
   feed uses `FeedVideos`/`InfiniteVideoFeed`; horizontal recognition must not
   steal near-vertical drags, taps, double-tap-like actions, DM reply focus, or
   right-rail interactions. Spike thresholds before polishing UI.

2. **Relay kind rejection.** Mobile publishing is inert until the relay accepts
   the new kind. Treat allow-listing as a dependency before declaring the loop
   end-to-end.

3. **Kind collision or wrong range.** Use a regular-range kind. Avoid 30k
   addressable kinds because swipe events are append-only feedback, not
   replaceable records.

4. **Don't wire tuning into removal.** Tuning advances by paging, not by
   removing (Decision 8). A reviewer should confirm a tuning swipe never adds to
   `removedVideoIds` or calls `_onRemoveVideo` — otherwise it behaves like
   deletion/block/mute and the video vanishes instead of just scrolling past.

5. **High-volume publishing.** Swipes can be rapid. The repository should
   tolerate concurrent calls, and the BLoC should debounce duplicate commits for
   the same visible video while a dismissal is in flight.

6. **Public signal semantics.** "Less" events are public. The UI should not
   describe them as private. Backend ingestion must also treat them as
   recommendation input only, never moderation/blocking.

---

## Testing

Repository package tests:

- Builds `more` and `less` events with the final kind, empty content,
  `direction`, `e`, `p`, `k`, and `t` tags.
- Includes `a` only when the addressable coordinate is trustworthy.
- Uses relay hints correctly without empty placeholder fields.
- `more` and `less` differ only by direction.
- `undo` publishes a kind-5 deletion with `e` and `k` tags for the tuning
  event.
- Expected publish/network failures are not reported; invariant failures are
  reported through the reporter port.

BLoC tests:

- Committed `more`/`less` resolves the current video and calls the repository
  with the right direction.
- Commit with no resolvable active video is a no-op.
- The handler does not add to `removedVideoIds` or call `_onRemoveVideo`.
- Undo with an event id calls repository `undo`; a null id is a no-op.
- `lastTuningAction` outbox is set on commit and cleared once consumed.

Widget/accessibility tests:

- Horizontal drag past threshold dispatches a tuning event; below threshold
  dispatches none.
- Vertical drag still pages the feed and does not tune.
- Indicator appears with localized labels and semantic actions.
- Snackbar Undo dispatches the undo event.
- L10n test covers new ARB keys and generated files.

Manual/device checks:

- Threshold feel on iOS and Android.
- Haptic fires once at threshold crossing.
- Right rail buttons, tap-to-pause, comments, DM reply bar, keyboard behavior,
  and feed settings remain usable.
- No jank from publish work on gesture commit.

---

## Backend Handoff (Deferred — Canonical Contract)

The Event Contract above is the **canonical interface** to the deferred
funnelcake/Gorse work. That side reads these events off the relay and maps them
into Gorse feedback to reshape `GET /api/users/{pubkey}/recommendations`. The
backend must honor:

- **Key the Gorse item on the `e` tag** (always present). Treat `a` / `k` / `p` /
  `t` as enrichment, and tolerate `e`-only events.
- `direction` = positive/negative feedback; `pubkey` = the user; the latest event
  by `created_at` wins for a `(user, target)` pair; a NIP-09 kind-5 deletion
  retracts a prior signal.
- **Recommendation input only** — never moderation, blocking, or reporting.

Two cross-repo blockers are owned jointly and must be settled before the loop is
live end-to-end:

1. **The kind number** is pinned to `4242` on mobile; backend ingestion must use
   the same constant.
2. **Relay allow-listing** of that kind.

A ready-to-use briefing prompt for the funnelcake/Gorse agent is maintained
alongside this work; it embeds this same contract so the backend agent needs no
access to this repo.

## Possible v1 Cuts

Safe cuts if implementation pressure is real:

- Undo. Latest-wins plus swiping the other way already corrects intent; ship the
  snackbar without retract, or defer Undo to a fast-follow.
- Coach mark. Gesture and accessibility actions still work without it.
- Animated tilt polish. Keep the indicator and translation.

Not recommended to cut:

- Accessibility actions. Gesture-only tuning is not acceptable.
- Kind coordination. Mobile, relay, and backend must agree on `4242` before the
  feature flag is enabled.
