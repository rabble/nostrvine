# Swipe-to-Tune Feed Recommendations — Design

**Date:** 2026-06-25
**Status:** Approved (brainstorm) — ready for implementation plan
**Scope of this spec:** divine-mobile client only

---

## Summary

Let users directly shape their own recommendation algorithm by swiping on
the video feed:

- **Swipe right** = "more like this" (love it, want more).
- **Swipe left** = "less like this" (not for me, want less).

Each swipe registers a signal and advances the feed (fast, Tinder-like
rhythm). The signal is published to the relay as a public, append-only
Nostr event. A later, separately-specced backend change has funnelcake
read these events off the relay and feed them into Gorse to reshape the
user's personalized recommendations.

This is **feed-shaping, not a social reaction.** A NIP-25 reaction (the
Like / heart) is a *public expression about content*. A swipe is a
*personal instruction to your own algorithm*. They are deliberately
distinct: you can like a video without wanting more of it, or want more
without publicly liking it.

### What this spec covers vs. defers

| In scope (this spec) | Deferred (separate spec) |
|---|---|
| The horizontal swipe gesture + in-gesture indicators | Funnelcake ingestion of the events off the relay |
| Publishing the feed-tuning Nostr event | Gorse feedback-model mapping / reranking |
| The new `feed_tuning_repository` package | Relay kind allow-listing (ops task, see Risks) |
| `FullscreenFeedBloc` wiring + feed advance | Reserving the kind number in the registry-of-kinds |
| Undo + accessibility + tests | Any "interests list" / cross-device sync surface |

The event contract below is defined precisely so the backend work can
consume it without further negotiation.

---

## Decisions (and the reasoning behind them)

These were settled during brainstorming; recording them so the rationale
isn't re-litigated during implementation.

1. **Mobile client end-to-end first.** Ship the gesture + the published
   event now; backend ingestion is a follow-up. The event contract is the
   interface between the two.

2. **A swipe is private feed-shaping, not a public reaction.** It is
   conceptually separate from the Like. We do **not** reuse kind 7.

3. **Stored publicly (plaintext).** "Personal" means *shapes my feed*,
   not *secret*. The event is plaintext so funnelcake/Gorse can read it
   straight off the relay. (We considered NIP-44 encryption-to-self and
   encryption-to-the-service; both were rejected because the chosen model
   is "public personal-preference event" — simplest to ingest, and the
   user is comfortable with the signals being public.)

4. **Append-only feedback events, latest-wins.** Each swipe is one small
   immutable event. This maps 1:1 onto Gorse's feedback model
   (user, item, feedback-type, timestamp) and avoids the
   write-amplification / lost-update races of a single rewritten
   preference list. "Changed your mind" = a newer event supersedes by
   `created_at`.

5. **Dedicated Divine feed-tuning kind — NOT NIP-32 kind 1985.**
   NIP-32 Labeling (kind 1985) was evaluated and initially recommended
   because it is purpose-built to attach labels to events/people/topics.
   It was **rejected** because kind 1985 is the channel distributed-
   moderation tooling scans: even namespaced, a high-volume stream of
   `less` labels targeting creators can be read by a naive or hostile
   aggregator as crowd-sourced downranking / soft-moderation of those
   creators (a reputation/harassment vector), and it pollutes the
   labeling space that moderation tools query. Instead we use a
   **use-case-specific microstandard** — our own dedicated kind that no
   moderation tooling reads — which is exactly what the NIPs registry
   steers toward (it marks NIP-90 DVMs "unrecommended… prefer
   use-case-specific microstandards"). We still **borrow NIP-32's
   targeting conventions** (`e`/`a`/`p`/`t` tags) on our own kind.

6. **Fast dismiss + advance for both directions.** Any horizontal swipe
   registers the signal and advances to the next video — a quick rhythm
   for rapidly training the feed. (We accept the minor contradiction of
   leaving a video you "love"; velocity of training was preferred over
   lingering.)

7. **Keep the `p` (creator) tag on both `more` and `less`.** A variant
   that dropped `p` on `less` events (to avoid any public anti-creator
   statement) was offered and **not** chosen — generalization to the
   creator is wanted on both directions.

8. **Not a block/mute.** Feed-tuning feeds recommendations only. It never
   writes to the NIP-51 mute list / blocklist. Distinct concern, distinct
   system.

---

## The relay contract (the interface to the backend)

A new **regular (append-only) Nostr event kind**, owned by Divine.

```jsonc
{
  "kind": 3XXXX,           // dedicated Divine "feed-tuning" kind.
                           // Regular range (1000–9999 per NIP-01) so relays
                           // store it. FINAL NUMBER TBD — see Open Items.
  "content": "",           // empty; everything indexable lives in tags
  "tags": [
    ["direction", "more"],                              // or "less"
    ["a", "34236:<authorPubkey>:<dTag>", "<relayHint>"],// the video (addressable)
    ["e", "<videoEventId>", "<relayHint>"],             // the video (event id)
    ["p", "<authorPubkey>"],                            // creator (generalize)
    ["t", "<hashtag>"]                                  // 0..n topic tags (generalize)
  ]
}
```

### Contract rules

- **Direction** is carried in a single `["direction", "more"|"less"]`
  tag. One kind, two directions (not two kinds).
- **Video reference uses BOTH `a` and `e`.** Divine videos are
  addressable kind 34236 (NIP-71). Per the repo's dual-tag rule, clients
  reference addressable events by either coordinate (`a`) or id (`e`);
  include both so the backend can match on whichever it indexes.
- **`p` (creator)** and **`t` (topics)** are included on **both**
  directions so Gorse can generalize beyond the single item ("less of
  this creator", "less of #fitness"). Topics come from the video event's
  own hashtag (`t`) tags. If a video has no hashtags, no `t` tags are
  emitted.
- **Append-only, latest-wins by `created_at`.** No `d` tag; this is not
  addressable/replaceable.
- **Undo = NIP-09 deletion.** An Undo publishes a kind-5 deletion
  request referencing the just-published feed-tuning event id. (Latest-
  wins already self-heals a corrected opinion; the explicit deletion is
  for accidental swipes.)
- **Reader:** only funnelcake/Gorse is expected to read these (filtered
  by our kind). Other clients MAY, but nothing depends on it.

---

## Mobile architecture

Follows the repo's layered flow: **UI → BLoC → Repository → Client.**

### Data/Client layer — no changes

`nostr_client` (`mobile/packages/nostr_client`) already publishes
arbitrary kinds via `publishEvent(Event)`. No changes needed.

### Repository layer — new package `feed_tuning_repository`

`mobile/packages/feed_tuning_repository` (pure Dart, ships with tests).

- **Responsibility:** own the construction and publishing of feed-tuning
  events. This is the only place that knows the kind number and tag
  layout.
- **Public API (shape, not final):**
  ```dart
  /// Publishes a "more like this" feed-tuning signal for [video].
  /// Fire-and-forget; returns the published event id for Undo, or null
  /// if no signer / publish could not be attempted.
  Future<String?> tuneMore(VideoEvent video);

  /// Publishes a "less like this" feed-tuning signal for [video].
  Future<String?> tuneLess(VideoEvent video);

  /// Retracts a previously-published signal via a NIP-09 deletion.
  Future<void> undo(String feedTuningEventId);
  ```
- **Dependencies:** constructor-injected `nostr_client` (or the signer +
  client abstraction the other repos use) and a nullable
  **reporter-port** typedef for Crashlytics (per the error-handling
  rule for pure-Dart packages — see `dm_repository` precedent). Owns its
  own `FeedTuningRepositoryReportableSites` constants.
- **Constants:** the kind number and namespace strings live in a
  constants class in this package (no hardcoded literals in call sites),
  cross-referenced with `lib/constants/nostr_event_kinds.dart`.
- **Failure contract:** fire-and-forget; network/relay failures are
  expected and NOT reported to Crashlytics (per the decision matrix).
  Programming-invariant violations are wrapped via the reporter port.

### Business-logic layer — `FullscreenFeedBloc`

Extend the existing `mobile/lib/blocs/fullscreen_feed/fullscreen_feed_bloc.dart`.

- **New events:** `FullscreenFeedTunedMore` / `FullscreenFeedTunedLess`
  (carry the target `VideoEvent` / index).
- **Handler:** calls `feedTuningRepository.tuneMore/tuneLess`, then
  advances by **reusing the existing video-removal path**
  (`removedIdsStream` / current removal mechanism) — no new
  feed-navigation machinery.
- **Undo:** the handler exposes enough state (the published event id) for
  the UI's Undo affordance to call `undo(...)` and re-insert the video.
- **No error strings in state.** Status enum + `addError` only.
- The repository is injected; if the bloc is constructed in a
  `ConsumerWidget`/`BlocProvider.create` that reads a Riverpod-provided
  `feedTuningRepository` whose identity can flip on auth change, apply
  the existing record-`ValueKey` bridging rule (see
  `state_management.md`). Confirm the provider's identity stability
  during implementation; gate on readiness (Pattern A) if available.

### Presentation layer — the gesture + indicators

Horizontal-drag detection on the feed item, dispatching tune events to
the bloc. Extracted into small private widget classes (no
`Widget`-returning methods).

---

## UX & feedback

### Gesture

- **Horizontal drag** on the active feed item. Both directions dismiss +
  advance once the commit threshold is crossed.
- **Angle/threshold disambiguation:** near-vertical drags must still go
  to the vertical pager (advance/rewind video). Only drags past a
  horizontal angle + distance threshold count as tuning. This is the top
  implementation risk (see Risks).

### In-gesture indicators ("subtle")

- An **edge-anchored indicator** (a `DivineIcon` + a short `context.l10n`
  label) **fades in, brightens, and scales with drag progress** — a small
  nudge barely shows it; a committing drag makes it solid.
- **Direction is color- and glyph-coded:** `more` = warmer/brighter with
  an upward/positive glyph; `less` = cooler/dimmer with a downward glyph.
  Exact `VineTheme` tokens chosen at implementation, contrast-checked per
  `accessibility.md`.
- The **video translates/tilts** with the finger so it physically feels
  like pushing it away (right) or toward (left).
- **Haptic tick** fires when the drag crosses the commit threshold; the
  indicator locks solid. Release past threshold commits; release before
  threshold snaps back and publishes nothing.

### Discoverability

- A **one-time coach-mark** (faint left/right chevron hint) on the first
  feed session, dismissed on first use. No permanent on-screen chrome.

### Accessibility

- The gesture surface is wrapped in `Semantics` with directional labels.
- On commit, announce "More like this" / "Less like this" via
  `SemanticsService.sendAnnouncement(View.of(context), …,
  Directionality.of(context))`.
- All copy via `context.l10n` (new ARB keys added + `flutter gen-l10n`).

### Undo

- After a swipe, a brief snackbar with **Undo**. Tapping it calls
  `feedTuningRepository.undo(eventId)` (NIP-09 deletion) and re-inserts
  the dismissed video into the current feed position.

---

## Risks & mitigations

1. **Gesture conflict (highest risk).** The native pooled player /
   `infinite_video_feed` may already claim horizontal drags, and vertical
   paging must keep winning on near-vertical drags. Mitigation: implement
   explicit angle + distance disambiguation; verify vertical paging,
   double-tap-like, and any existing overlays are unaffected. Spike this
   first.
2. **Relay kind allow-listing (ops, deferred).** The divine relay rejects
   some unknown kinds by policy. The new kind must be allow-listed before
   the loop works end-to-end. We control the relay; this is config, not a
   code blocker, but the mobile feature is inert until it's done. Track
   as a dependency of the backend spec.
3. **Kind number collision.** No central allocator forces a number;
   reserve it in the registry-of-kinds and pick an unused regular-range
   value to avoid ambiguity for any client reading multiple kinds.
4. **Volume.** Swiping is high-frequency. Publishing is fire-and-forget
   and debounced per video (one in-flight per video; re-swiping replaces
   intent). Confirm no UI jank from publish on the gesture thread.

---

## Testing

- **`feed_tuning_repository` (new package — tests required in same PR):**
  - event construction: correct kind, `direction` tag, `a`/`e`/`p`/`t`
    tags derived from a `VideoEvent` (incl. the no-hashtags case);
  - `more` vs `less` differ only by the `direction` value;
  - `undo` builds a correct kind-5 deletion referencing the event id;
  - reporter-port: expected network failures are NOT reported;
    invariant violations ARE wrapped/reported.
- **`FullscreenFeedBloc` (`blocTest`):** `FullscreenFeedTunedMore/Less`
  call the repository and advance the feed; Undo re-inserts.
- **Widget tests:** drag past threshold publishes + advances; drag below
  threshold snaps back + publishes nothing; indicator + `Semantics`
  present; Undo path; `MaterialApp` carries
  `AppLocalizations.localizationsDelegates` / `supportedLocales`.

---

## Open items to finalize during implementation

- **Final kind number** (reserve via registry-of-kinds; add to
  `nostr_event_kinds.dart` + the new package's constants).
- **Exact `VineTheme` color tokens + `DivineIcon` glyphs** for the two
  directions (contrast-checked).
- **Commit threshold values** (angle, distance, velocity) for the gesture
  disambiguation — tuned on-device.
- **Whether a `k` tag** (stringified target kind `34236`) is worth adding
  for the backend's convenience — cheap; decide with the funnelcake spec.

---

## Possible v1 scope cuts (if needed)

These can be deferred without changing the contract:

- **Undo** (latest-wins + a future re-swipe already corrects intent).
- **One-time coach-mark** (gesture still works without it).

Neither is recommended to cut unless implementation pressure requires it;
both are small.
