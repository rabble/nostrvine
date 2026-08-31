# Brainstorm: naming a vanished DM peer consistently in inbox search

Date: 2026-08-27

Seeded by `tasks/findings_8204.md` (local-only; `tasks/` is in
`.git/info/exclude`). Issue: #8204. Related: #8185 / PR #8196 (merged
`ab98417e2`), #8205 / PR #8207, #8208 (reopened).

## Problem Statement

The DM inbox resolves a conversation peer's name **twice, independently**. The
row renders through `dmPeerDisplayName` — a five-step chain that puts a NIP-62
vanish first. The search index matches through `ConversationListBloc`, which
implements only the last two steps of that chain. So a row can display
"Deleted account" while the index holds a generated "Adjective Animal N" the
viewer has never seen: searching what is on screen finds nothing, and searching
an invisible string finds the row.

The bug is not a missing vanish check. It is a **second naming chain that was
never required to stay in sync with the first** — which is why the same
expression also mis-names a retired-Divine-Moderation thread.

## Constraints

- **Layering.** `.claude/rules/architecture.md`: filtering is BLoC/repository
  work, never UI work. So the match must stay in the BLoC — the UI cannot be
  handed the filtering back.
- **Localization.** `.claude/rules/localization.md`: "Strings stay in the UI
  layer — BLoCs emit status enums, the UI maps them." A BLoC may not import
  `context.l10n`. Any label it matches on must be **injected**.
- **The labels are not constant.** There is a live in-app language picker
  (`LocaleCubit`, `mobile/lib/blocs/locale/locale_cubit.dart`; Settings →
  General, `general_settings_screen.dart:326`) which rebuilds `MaterialApp`
  with a new `locale` **without restarting the app**. `BlocProvider.create:`
  runs once, so a label injected only at construction goes stale on a language
  change.
- **The vanish signal must be live, not sampled.** `ProfileRepository.isVanished`
  is an in-memory mirror seeded by an `unawaited` `loadVanishedPubkeys()`
  (`repository_providers.dart:402`); the row instead watches the durable
  `vanished_profiles` Drift table. Sampling the mirror reopens the bug at cold
  start and whenever a vanish is discovered after indexing (findings F12).
- **The batch response cannot carry the signal.** Measured against a funnelcake
  built from `origin/main`: of five reachable vanish states, `POST /api/users/bulk`
  yields a usable vanish signal in exactly one (findings F13). A pending vanish
  is stripped from both `users` and `missing`.
- **No protocol constraint.** NIP-62 is silent on rendering, naming and search;
  no NIP defines a deleted-account label or a kind-0-absent fallback (findings
  F10). This is entirely a client product decision.
- BLoC-first, constructor injection, no new Riverpod.

## Prior Art

- `mobile/lib/screens/inbox/widgets/dm_peer_identity.dart` — the canonical
  five-step chain, shipped by #8196. Its own doc comment explains why vanished
  must come first.
- `mobile/lib/screens/inbox/widgets/moderation_identity.dart` — step 3,
  answering for retired keys too.
- `ConversationListProfileRepositoryChanged` + `_InboxRepositorySync`
  (`inbox_page.dart`) — the established pattern for **delivering a changing
  dependency into this BLoC in place**, chosen deliberately over a `ValueKey`
  because re-keying would lose tab selection, scroll offset and search text.
  This is the precedent a label channel should copy.
- `supportRowPubkey` (`inbox_page.dart:108`) — precedent for injecting a
  configuration value into this BLoC at construction.
- PR #8207 (#8205) — the sibling fix for reaction rows, which moved two more
  surfaces onto `dmPeerDisplayName` rather than re-deriving the branch.

## Approaches Explored

### Approach A: add the branches to `_applyFilters`

**Description:** Teach the BLoC's filter about vanished and moderation inline —
two extra conditions in `_applyFilters`, plus the injected labels and the
vanished set.

**Layers affected:** BLoC, UI (label + vanished-set delivery).

**Pros:** smallest diff; no new file; entirely inside the failing function.

**Cons:** leaves **two hand-maintained copies** of the precedence. The render
chain has already grown twice (moderation in #6283, vanished in #8196) and each
growth is what created this bug; a third would diverge again by default. It
fixes the instance, not the class.

**Complexity:** Low.

### Approach B: store the rendered name in `profileNames`

**Description:** Make the index hold exactly the string the row displays, so
index and row are one value by construction.

**Layers affected:** BLoC, UI, and every consumer of `profileNames`.

**Pros:** the strongest possible guarantee — there is nothing left to keep in
sync.

**Cons:** the UI can only compute names for **rendered** rows, and
`_resolveMissingProfileNames` exists precisely to index rows that are not on
screen, so a UI-sourced value is structurally incomplete. The BLoC must compute
it anyway — at which point this collapses into Approach C plus a semantic change
to `profileNames` affecting unrelated call sites. Largest blast radius for no
extra correctness over C.

**Complexity:** High.

### Approach C: extract one shared, Flutter-free resolver — **chosen**

**Description:** Lift the precedence out of the widget layer into a pure
function parameterized by its labels. `dm_peer_identity.dart` keeps its
`BuildContext` signature and delegates, passing `context.l10n.*`;
`ConversationListBloc` calls the same function with labels injected through the
existing in-place delivery channel. One precedence, two callers.

**Layers affected:** a new pure helper, the widget chain, the BLoC, and the UI
sync widget.

**Pros:** a future branch is added **once** and both surfaces get it — this
fixes the class, not the instance. The pure function is directly unit-testable
without a widget pump. The BLoC stays Flutter-free and l10n stays owned by the
UI, so both governing rules hold. It reuses the delivery pattern the file
already documents rather than inventing one.

**Cons:** more moving parts than A: a new file, a labels value type, and a
second in-place delivery channel. The widget chain must delegate rather than be
replaced, so `ConversationTile`'s behaviour stays byte-identical.

**Risks / Unknowns:** the labels channel must fire on locale change, or the fix
introduces a stale-language bug it did not have before. Mitigated by dispatching
from a widget that reads `context.l10n` in `build` and compares before
dispatching.

**Complexity:** Medium.

### Approach D: suppress instead of replace

**Description:** Stop indexing the generated fallback for a vanished or
moderation row — index the empty string — so the invisible handle stops
matching.

**Pros:** trivially small; satisfies acceptance criterion 2.

**Cons:** does **not** satisfy criterion 1 — "Deleted account" still finds
nothing, and the row becomes findable only by message text. Half a fix that
reads as a whole one.

**Complexity:** Low.

## Recommendation

**Approach C**, scoped to **both** the vanished and the retired-moderation
branch, matching on the **localized label only** (no npub/hex) — all three
confirmed with the issue owner.

C is the only option that addresses the actual root cause. A and D treat the
symptom in the function where it surfaced; B pays a large refactor for a
guarantee C already provides. C also matches how #8196 and #8207 were built:
both moved surfaces **onto** the shared chain rather than re-deriving a branch,
and this extends that same consolidation one layer down so a non-widget caller
can join it.

Label-only matching is consistent with the shipped #8196 product decision —
a vanished peer gets an identity-neutral reference, not a competing name — and
adding pubkey matching would introduce a capability no other inbox row has,
inside a bug fix.

## Open Questions for /plan

- [x] Where does the vanished set come from? → a new
      `Stream<Set<String>> watchVanishedPubkeys()` on `ProfileRepository`,
      a thin passthrough to `vanishedProfilesDao.watchAllPubkeys()`. The
      repository already imports `db_client`, already holds the DAO, and already
      exposes `watchProfile` / `watchProfileStats` / `watchPendingSave`, so this
      is idiomatic and adds no dependency. Subscribing (rather than sampling
      `isVanished`) is what satisfies the live-signal constraint.
- [x] How do labels reach the BLoC without staleness? → a
      `ConversationListPeerLabelsChanged` event, dispatched from the inbox's
      existing sync widget, mirroring `ConversationListProfileRepositoryChanged`.
- [ ] Does the subscription need re-establishing when `_profileRepository` is
      swapped in place? (Almost certainly yes — resolve in the plan.)
- [ ] Does the message-requests screen (`message_requests_page.dart`, the second
      `ConversationListBloc` construction site) need the same wiring, or does it
      never search?
- [ ] Exact placement of the pure resolver: alongside the BLoC, or in
      `packages/models`? It must not import Flutter.

## Prerequisites

None. No design input, no new package, no protocol decision, no team sign-off —
the naming decision was settled by #8196 and re-confirmed above.

## Next Step

`/plan 8204`.
