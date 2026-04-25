# Content Policy Layer — Design

## Problem

Users are seeing content from authors they have blocked or muted. The pattern is recurring — issue #948 reported exactly this for search in February, was closed, and the leak has returned. A full audit (see the expanded comment on #948) found that blocked-author content leaks in comments, video search, user search, hashtag feeds, other-user profile feeds, and likely notifications. Only the primary feeds, video detail screen, and DM conversations apply filtering.

The root cause is architectural. The app has **three overlapping content-moderation services** — `MuteService` (dead code, `lib/services/mute_service.dart`), `ContentModerationService` (dead code, `lib/services/content_moderation_service.dart`), and `ContentBlocklistRepository` (the only one wired up). Filtering is applied at the presentation layer on a per-surface basis via `.where(!shouldFilterFromFeeds(...))` calls in feeds and providers. Every new feed has to remember to call the filter, and most don't.

Patching each surface one-at-a-time is how #948 reopened. The fix is to move the policy boundary down, not sideways.

## Goals

- Make filtering a property of the system, not a convention every feature must re-apply.
- Consolidate the three overlapping services into one policy engine + one state source.
- Leave room for hashtag/keyword filters, subscribed moderation lists, NSFW/age gates, and future rules without re-architecting.
- Preserve a hard invariant: the app must never tell a user they have been blocked by someone else.
- Avoid churn — scope Phase 1 tightly enough to ship with confidence, design the interface broadly enough that the deferred features don't require rework.

## Non-Goals

- Admin/moderator view of unfiltered content. Handled in a separate tool; nothing in this app bypasses the policy layer.
- Write-time cache-invalidation framework. The dominant content caches are session-scoped (Riverpod/BLoC state); the only persistent event cache is `PersonalEventCacheService` which holds the current user's own events by definition.
- Retroactive disk scrubbing on new mute. Nothing on disk stores third-party event content.
- Server-side filtering. Funnelcake and relays remain unaware. All filtering is client-side.
- Relay-side NIP-42 auth / protected subscription handling. Orthogonal.
- Hashtag/keyword/subscribed-list rules. Interface supports them; implementation deferred.

## Invariants

Four invariants that every component in the design must uphold.

### 1. Ingress invariant

Blocked content must not cross an app ingress boundary into app state. The filter runs at repository parse boundaries, REST model-construction loops, and relay-subscription delivery seams. If the policy engine says block, the event or model is dropped before it is cached, exposed to app subscribers, or rendered by downstream features.

### 2. Interaction invariant

The app must not offer UI affordances for interactions the recipient has blocked. When the current user's local state indicates a target pubkey has blocked us (via that pubkey's published kind 10000 or kind 30000 block list), UI affordances targeting that pubkey — follow, DM, reply, mention, tag, share-to — must be hidden, not greyed-out with an explanation, not disabled with a tooltip. Absent, full stop.

### 3. Disclosure invariant

The app must never tell a user they have been blocked by another user. No badge, no error message, no empty-state copy, no tooltip, no remote log, no analytics event that reveals the block relationship to the blocked user or to third parties. Plausible deniability: absence of an affordance may be inferred as many things; we never confirm.

### 4. Cross-app honesty

These invariants describe the behavior of *this* app. They do not prevent the user from publishing mentions, replies, or DMs via any other Nostr client. The spec is honest that this is UX policy, not protocol-level enforcement. Any "we prevent X" language in code comments or user-facing copy must be accurate about this boundary.

## Architecture

```
                    ┌──────────────────────────────────┐
                    │     ContentPolicyEngine          │
                    │     (pure Dart, no Flutter)      │
                    │                                  │
                    │   evaluate(PolicyInput,          │
                    │            ContentPolicyState)   │
                    │     → PolicyDecision             │
                    │                                  │
                    │   canTarget(pubkey,              │
                    │             ContentPolicyState)  │
                    │     → bool                       │
                    │                                  │
                    │   composed of ordered            │
                    │     List<PolicyRule>             │
                    └──────────────────────────────────┘
                               ▲
                               │
                 ┌─────────────┼─────────────┐
                 │                           │
      ┌──────────┴────────┐       ┌──────────┴────────┐
      │ parse-gated       │       │   canTarget()     │
      │ NostrEventParser  │       │   queried by UI   │
      │ VideoEvent.fromJson│      │   affordance gates │
      │ etc.              │       │                   │
      │                   │       │                   │
      │ JSON/relay event  │       │                   │
      │ → app model?      │       │                   │
      │ (null = dropped)  │       │                   │
      └───────────────────┘       └───────────────────┘
                ▲
                │
      ┌─────────┴──────────┐
      │ NostrClient /      │
      │ FunnelcakeClient   │
      │ receive raw JSON / │
      │ raw relay events;  │
      │ blocked content is │
      │ dropped at app     │
      │ ingress seams      │
      └────────────────────┘
```

**ContentBlocklistRepository** (already extracted per #3227) owns persistence, Nostr publish, and relay sync of mute/block state. It exposes a synchronously-hydrated `ContentPolicyState` snapshot plus a `Stream<ContentPolicyState>` for updates. The engine reads state on every evaluation; it is itself stateless.

The architecture has **two query shapes** on one engine:

- `evaluate(input, state) → PolicyDecision` — ingress filtering. Used by parsers.
- `canTarget(pubkey, state) → bool` — affordance gating. Used by UI code deciding whether to render a Follow/DM/mention control.

These are distinct surfaces with distinct call sites and distinct failure modes. Combining them into one API that returns a rich decision object was considered and rejected because callers in the UI don't need (and must not leak) the reason.

## Components

### 1. `content_policy` package

New package at `mobile/packages/content_policy/`. No Flutter deps. 100% unit-testable.

#### `PolicyInput`

```dart
class PolicyInput {
  const PolicyInput({
    required this.pubkey,
    this.kind,
    this.content,
    this.tags,
  });

  final String pubkey;
  final int? kind;
  final String? content;
  final List<List<String>>? tags;
}
```

Minimal contract. Parsers construct this from the parts of the JSON they already need to read (pubkey is at a fixed key in the Nostr envelope). For Phase 1, only `pubkey` is consulted by rules.

#### `PolicyDecision`

```dart
sealed class PolicyDecision {
  const PolicyDecision();
}

final class Allow extends PolicyDecision {
  const Allow();
}

final class Block extends PolicyDecision {
  const Block({required this.ruleId});
  final String ruleId;  // diagnostics only, release builds never surface
}

// Reserved for later; not implemented in Phase 1:
// final class SoftHide extends PolicyDecision { ... }
// final class Warn    extends PolicyDecision { ... }
```

`Block` carries a `ruleId` for local diagnostics only. Must not appear in user-visible copy, release-build logs, remote telemetry, Crashlytics breadcrumbs, or analytics events.

#### `PolicyRule`

```dart
abstract interface class PolicyRule {
  String get id;
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state);
}
```

Rules are pure functions. No IO, no async. They read from the `ContentPolicyState` snapshot passed into each call.

#### `ContentPolicyEngine`

```dart
class ContentPolicyEngine {
  const ContentPolicyEngine(this.rules);
  final List<PolicyRule> rules;

  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    for (final rule in rules) {
      final d = rule.evaluate(input, state);
      if (d is Block) return d;
    }
    return const Allow();
  }

  bool canTarget(String pubkey, ContentPolicyState state) {
    return !state.isBlockedBy(pubkey);
  }
}
```

- Rules are evaluated in order. Short-circuits on first `Block`.
- `canTarget` is a simple read from `ContentPolicyState` — the mutual-mute list. It does not run the full rule pipeline; it answers one specific question.

#### Rule ordering is load-bearing

`SelfReferenceRule` must be first. A malformed mute list that includes the current user's own pubkey would otherwise filter the user's own content, reproducing #2192. The engine constructor asserts `SelfReferenceRule` is at position 0 when constructed from the default rule set.

### 2. `ContentPolicyState`

Immutable value type. The engine never mutates it; it is rebuilt by `ContentBlocklistRepository` when source data changes.

```dart
class ContentPolicyState {
  const ContentPolicyState({
    required this.currentUserPubkey,
    required this.mutedPubkeys,           // user muted these (kind 10000)
    required this.blockedPubkeys,         // user blocked these (kind 30000 d=block)
    required this.pubkeysBlockingUs,      // from kind 30000 events naming us
    required this.pubkeysMutingUs,        // from kind 10000 events naming us
  });

  bool isAuthorFiltered(String pubkey) =>
      mutedPubkeys.contains(pubkey) ||
      blockedPubkeys.contains(pubkey) ||
      pubkeysBlockingUs.contains(pubkey) ||
      pubkeysMutingUs.contains(pubkey);

  bool isBlockedBy(String pubkey) =>
      pubkeysBlockingUs.contains(pubkey) ||
      pubkeysMutingUs.contains(pubkey);
}
```

All four sets are `Set<String>` of hex pubkeys. O(1) lookup.

An empty `ContentPolicyState` (no current user, empty sets) is the default during pre-hydration. See "State hydration" below for why this is a correctness concern.

### 3. Phase 1 rules

All ship with the engine. All consult only `PolicyInput.pubkey` plus `ContentPolicyState`.

| Rule | Behavior |
|---|---|
| `SelfReferenceRule` | If `input.pubkey == state.currentUserPubkey`, returns `Allow` and short-circuits. Must be at position 0. |
| `PubkeyMuteRule` | `Block` if `state.mutedPubkeys.contains(input.pubkey)`. |
| `PubkeyBlockRule` | `Block` if `state.blockedPubkeys.contains(input.pubkey)`. |
| `MutualMuteRule` | `Block` if `state.pubkeysBlockingUs.contains(input.pubkey)` or `state.pubkeysMutingUs.contains(input.pubkey)`. |

### 4. Parse-gate integration

The parse-gate is **direct integration**, not a wrapper class. The engine is injected into the existing parser constructor. There is no "raw parser" API surface.

Affected parse boundaries (to be audited and mapped in the implementation plan):

- `NostrEvent.fromJson` / the app's Nostr event parsing entry point.
- `VideoEvent.fromJson` and related model `fromJson` constructors in `mobile/packages/models/`.
- Funnelcake REST response deserialization paths (e.g. `getVideosByAuthor`, `search`, `getFeed`, `getHashtagVideos`, profile lookups).

For video content, the existing `videos_repository` `BlockedVideoFilter` seam is the intended enforcement point for both relay and Funnelcake REST responses. The implementation plan should treat that as the coverage mechanism for video REST paths rather than inventing a second video-only hook.

At each boundary:

```dart
Event? parse(Map<String, dynamic> json) {
  final pubkey = json['pubkey'] as String?;
  if (pubkey == null) return null;

  final decision = _engine.evaluate(
    PolicyInput(pubkey: pubkey, kind: json['kind'] as int?),
    _stateProvider(),
  );
  if (decision is Block) {
    _dropCounter.increment(decision.ruleId);  // dev builds only
    return null;
  }

  // ... existing parse + signature verification
  return Event(...);
}
```

For list-valued REST responses, iterate the raw items, short-circuit on blocked pubkeys, skip without constructing the model.

Blocked content is **never** allowed past the app ingress seam into app state, caches, or subscribers. Some low-level SDK objects may still exist transiently before the app-level seam decides to drop them; that is an accepted tradeoff to keep app policy out of the SDK.

### 5. Interaction gating (`canTarget`)

UI surfaces that target a specific pubkey consult `engine.canTarget(pubkey, state)` to decide whether to render the affordance.

Gated affordances (non-exhaustive; the implementation plan audits all):

| Surface | Behavior when `canTarget` returns false |
|---|---|
| Follow / Unfollow button on profile | Hidden |
| Send DM action on profile | Hidden |
| Reply compose on any event from them | Hidden (rarely reachable since content is filtered) |
| @-mention autocomplete | Excluded from suggestion list |
| Share-to-user picker | Excluded |
| Tag-in-video picker | Excluded |

Gating is **absence**, not a disabled state with explanation. No copy, no tooltip, no reason.

### 6. State source — `ContentBlocklistRepository`

Already exists (extracted per #3227). No rewrite. Adjustments:

- Expose `ContentPolicyState get currentState` — synchronous snapshot.
- Expose `Stream<ContentPolicyState> get stream` — emits on change.
- Ensure local-storage hydration is synchronous at app bootstrap (see "State hydration").
- Keep publishing responsibilities (kind 10000 mute publish, kind 30000 block publish, mutual-mute sync from relays) unchanged. PR #3188 already made these reliable; no change needed.

The `MutualMuteRule` reads from `pubkeysBlockingUs` / `pubkeysMutingUs`, which `ContentBlocklistRepository` already populates from subscribed kind 10000 / kind 30000 events.

## State hydration

**Invariant**: Policy state must be fully hydrated from local storage *before* the parse-gate accepts its first call.

The app bootstrap sequence must:

1. Open SharedPreferences / Hive boxes that persist the user's own mute and block lists.
2. Construct `ContentPolicyState` from those.
3. Register the engine with that state.
4. Only then open WebSocket subscriptions or kick off REST fetches.

Relay sync of mutual-mute data happens asynchronously after bootstrap. Until relay sync completes, the app knows *our own* mutes/blocks but not what other users have published about us. That's acceptable — during that window, the leak case is narrower (we would see content from users who blocked us until we fetch their kind 30000). This is a recognized and accepted window, not an invariant violation.

Relay sync emitting a new `ContentPolicyState` on the engine's stream is what triggers cache invalidation (below).

## Mute / unmute — cache invalidation

When the user adds a pubkey to their mute or block list:

1. `ContentBlocklistRepository` persists to local storage and publishes the updated kind 10000 / kind 30000 event (existing behavior from PR #3188).
2. `ContentPolicyState` stream emits a new snapshot.
3. Any in-memory session cache that could hold content from the newly-muted pubkey is invalidated:
   - Riverpod providers: `ref.invalidate(...)` on the relevant providers; they refetch through the parse-gate.
   - BLoCs: emit a `Refresh` event or equivalent; repositories refetch through the parse-gate.

Invalidation targets the dominant surfaces: home feeds, search, hashtag feeds, profile feeds, comments, notifications.

**What is *not* done:**

- No sweep of `PersonalEventCacheService` (it only holds the current user's own events).
- No sweep of image/video caches (content-addressed by URL; unreferenced media evicts via normal LRU).
- No scan of SharedPreferences / Hive for content fields (we don't persist third-party content anywhere).

Unmute works identically — state changes, caches invalidate, next fetch re-populates through the gate.

## Migration plan

Four phases, each independently shippable. Feature-flagged under `content_policy_v2` until Phase 3.

### Phase 0 — Build the engine

- Create `content_policy` package with engine, rule interface, the four Phase 1 rules, `PolicyInput`, `PolicyDecision`, `ContentPolicyState`.
- 100% unit test coverage on the package (pure Dart, trivial to test).
- No integration with app yet. No surfaces routed.

### Phase 1 — Parse-gate integration

- Inject the engine into the Nostr event parser and model `fromJson` parsers under the `content_policy_v2` flag.
- When the flag is on, parse-gate applies. When off, parsers behave unchanged.
- `ContentBlocklistRepository` exposes `currentState` / `stream`.
- Bootstrap sequence hydrates policy state synchronously before any subscription or fetch opens.
- Integration tests: publish events from a muted pubkey through a fake NostrClient; assert they never reach any BLoC/Provider state.

### Phase 2 — Interaction gating

- Implement `canTarget` call sites in UI: follow, DM, mention autocomplete, share/tag pickers.
- Still feature-flagged.
- Widget tests assert affordances are absent when mutual-mute state names the target.
- Manual QA pass: walk through every known interaction surface, confirm invariants hold.

### Phase 3 — Enable and delete scattered filters

- Enable `content_policy_v2` in all builds.
- Remove every `.where(!shouldFilterFromFeeds(...))` call in feeds, providers, and BLoCs. The parse-gate now owns that work.
- Remove the `ContentBlocklistRepository` → `shouldFilterFromFeeds` call sites. Keep the method on the repository for a deprecation window; mark `@Deprecated`.
- Close #948.

### Phase 4 — Cleanup

- Delete `lib/services/mute_service.dart` (dead code).
- Delete `lib/services/content_moderation_service.dart` (dead code). File a follow-up issue to implement its subscribe-to-external-mute-list feature as a future `SubscribedListRule`.
- Delete `shouldFilterFromFeeds` from `ContentBlocklistRepository`.
- Remove the `content_policy_v2` flag.

## Testing strategy

Every layer has a clear test shape.

**Engine** (`content_policy` package): pure unit tests, table-driven per rule. No mocks. No Flutter. Assertions on input → output mapping for each `PolicyDecision` branch.

**Rule ordering**: test that `SelfReferenceRule` short-circuits even when later rules would block the pubkey. Test that engine construction asserts when `SelfReferenceRule` is not first.

**Parsers**: integration tests with a test engine whose rules are configurable. Publish synthetic events / decode synthetic JSON; assert `null` for blocked inputs, constructed model for allowed inputs.

**State hydration**: bootstrap test that constructs the app with a pre-populated mute list in SharedPreferences, asserts the engine state is ready before any subscription opens. Failure mode covered: engine queried during pre-hydration must return `Allow` (empty state) — we accept this as the documented startup window, not a bug.

**Cache invalidation**: test that emitting a new `ContentPolicyState` via the repository's stream causes the relevant providers / BLoCs to refetch.

**Surface regression tests** — the tests that would have caught #948 staying fixed:

- For each content surface (home, popular, for-you, search, hashtag, profile, comments, notifications), a widget/integration test that seeds a muted pubkey into repository state, asserts that pubkey's content is absent from the emitted BLoC/Provider state.

**Affordance gating tests**: widget tests that seed `pubkeysBlockingUs`, render the relevant UI, assert the affordance is absent. Do **not** assert on error copy, tooltip text, or any surface that would reveal the reason.

**Disclosure tests** (negative assertions):

- No copy string anywhere contains "blocked you", "blocked by", "not accepting" or equivalent — enforced by a source grep in CI.
- Release-build logs do not contain `MutualMuteRule` or pubkey literals from policy decisions — enforced by test harness.

## What this design deliberately rejects

- **Admin/unfiltered view** — moderation happens in separate tooling. No part of this app sees unfiltered content.
- **Stream-transformer / adapter pattern** — rejected in favor of parse-gate. Same guarantees, earlier application, no allocation of blocked objects, no signature-verify cost on blocked events.
- **Write-time filter at the cache boundary** — rejected in favor of parse-time. Blocked content never becomes an object.
- **Purge-on-mute disk sweep** — not needed. Session caches invalidate via provider refresh; no persistent third-party-content store exists.
- **Separate raw parser + `PolicyGatedParser` wrapper** — rejected. Bypass becomes a public type, DI gets ambiguous, drift risk. Single parser with engine injected.
- **`isBlockedByUser` exposed to BLoCs / UI** — rejected. `canTarget` returns a bool with no reason; `isBlockedBy` is private to the state class.
- **Rich failure reasons on blocked interactions** — rejected. Interaction attempts that would fail due to being-blocked must appear to succeed locally (optimistic UI) or fail with a generic network-style error.

## Open questions (resolve in implementation plan)

1. **Exact parse boundaries to route.** The implementation plan must audit every `fromJson` that converts remote data to an in-app model, plus every WebSocket event-handler entry point. A complete list goes in the plan, not the spec.
2. **How BLoCs currently invalidate on state change.** The plan picks a uniform invalidation signal (BLoC event vs. repository-owned stream the BLoC listens to). Existing patterns in the repo should drive this.
3. **Feature flag plumbing.** The app has an existing feature-flag mechanism (see `2026-04-02-feature-flags-entry-design.md`); the plan wires `content_policy_v2` into it.
4. **Whether `personal_event_cache_service.dart` needs any guard.** Per its ABOUTME it only holds the current user's own events; `SelfReferenceRule` covers that case. The plan confirms this by reading the code rather than the comment.

## Deferred — future work on this layer

Each of these is a follow-up issue, not in scope for Phase 1. The interface is designed so they fit without re-architecting.

- **`HashtagRule`** — check event tags for muted hashtags.
- **`KeywordRule`** — substring match on `content`. Needs its own performance budget (O(m) per event).
- **`SubscribedListRule`** — subscribe to external curators' kind 10000 / kind 30000 events, aggregate into policy state. Folds in `ContentModerationService`'s original intent.
- **NSFW / content-warning integration** — the existing `ContentFilterService` and moderated-content pipeline (see `2026-04-05-moderated-content-filter-design.md`) become additional rules or a sibling engine; scoping tbd.
- **Age-gate integration** — tie into the age-restricted viewer auth work (see `2026-04-17-age-restricted-viewer-auth-parity.md`).

## Related work and context

- **#948** (reopened 2026-04-23) — the recurring user report. This design closes it on Phase 3.
- **PR #3188** (merged 2026-04-20) — made mute/block publishing reliable. Upstream of this design. No overlap in scope.
- **#3227** (closed 2026-04-22) — renamed `ContentBlocklistService` → `ContentBlocklistRepository`. This design builds on that positioning.
- **Epic #604** — the umbrella "Content Moderation" epic. A new tracking issue for this design will link to #604.
- **`MuteService`**, **`ContentModerationService`** — deleted in Phase 4 per this design.
