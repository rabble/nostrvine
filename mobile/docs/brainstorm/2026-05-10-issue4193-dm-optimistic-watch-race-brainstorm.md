# Brainstorm: DM optimistic vs. watchMessages race in fresh conversations

Date: 2026-05-10

## Problem Statement

Sending a DM to a freshly-searched user produces no visible bubble in the
live `_ConversationContent`, even though the message persists across an
app restart (see #4193). The send path itself works — `direct_messages`
contains the rumor row by the time the user force-quits — but the
in-memory bridge between `_onMessageSent`'s optimistic emit and the
`watchMessages` stream that feeds `state.messages` can drop the
optimistic on a watch tick that fires before `sendMessage`'s persistence
transaction commits. We need to pick a fix that closes the race for the
user-visible bug without blocking the larger durable-queue work
already scoped under #3909 / #3912.

## Constraints

- **Layered architecture (`architecture.md`).** Fix lives at BLoC or
  Repository; UI must not start composing send-side and watch-side
  state.
- **No error strings in state, status enums + `addError`
  (`state_management.md`).** Optimistic markers are fine; error metadata
  is not.
- **No mutable instance variables on a BLoC class
  (`state_management.md`).** Any per-send tracking lives in `state`,
  not as a `final Map<String, …> _pending` on the bloc.
- **`BlocProvider` keyed on `(dmRepository, currentPubkey)` already
  recreates the bloc on auth flip (#3908).** Our fix must survive that
  recreate without leaking optimistic rows.
- **`outgoing_dms` already exists** (#3911). Schema, DAO, and
  `OutgoingDmsDao.watchForConversation` ship on `main`. The repository
  enqueues a row before publish and deletes it on full delivery; the
  retry service from #3909 hasn't landed yet.
- **`rxdart: ^0.28.0`** is in `mobile/pubspec.yaml` and in several
  in-repo packages (`comments_repository`, `sounds_repository`,
  `follow_repository`). Combine-latest is available, no new dep needed.
- **strict-coverage gate** on `mobile/packages/divine_ui` (not the
  layers we're touching here, but the rule applies if we widen any
  bubble component for delivery-status icons).
- **Don't ship #3909 as a side effect of this bug fix
  (`agent_workflow.md` §4 "no tech debt").** Scope-cut to the bug.

## Prior Art

- **Investigation in this repo:** see #4193 investigation summary
  produced by `/investigate` immediately before this brainstorm —
  identifies the suspect line ranges
  (`conversation_bloc.dart:46-72` `_onStarted`,
  `:87-189` `_onMessageSent`,
  `dm_repository.dart:790-951` `sendMessage`,
  `:1800-1804` `watchMessages`).
- **#3908** shipped the failure-path optimistic strip + retry SnackBar
  + `BlocProvider` keyed on repo identity. Pinned by
  `conversation_bloc_test.dart` (lines 236-290) and
  `conversation_view_test.dart` (`group('send-failure SnackBar', ...)`).
  Critically, **the success-path test never starts the watch stream**
  (`bloc.add(ConversationMessageSent)` without a prior
  `ConversationStarted`), so a watch tick mid-send is not pinned by any
  current test.
- **#3909 epic body** describes the principled fix as
  `Rx.combineLatest2(watchMessages, watchOutgoing)` with a parallel
  `Map<String, MessageDeliveryStatus>` keyed by rumor id, plus per-bubble
  delivery indicators (clock / single check / double check / error /
  cancelled).
- **In-repo optimistic precedents:**
  - `video_interactions_bloc.dart:209-261` — like / repost /
    self-comment optimistics. Repository writes the optimistic row first,
    BLoC emits the optimistic count + status, then awaits the network
    call and reconciles. The repository owns the rollback. Different
    shape (count + status booleans, not a list of rows) but same
    principle.
  - `comments_bloc.dart:619` — vote toggle reverts the optimistic to a
    pre-tap baseline on failure.
  - `my_following_bloc.dart:17` — initial state seeded optimistically
    from cache.
- **`OutgoingDmsDao.watchForConversation`** is already implemented and
  tested (`outgoing_dms_dao_test.dart:321`). Not yet exposed via
  `DmRepository`'s public API.
- **`tasks/lessons.md`** and `tasks/brainstorm_3688.md` —
  no prior brainstorm specifically on the DM optimistic race.

## Approaches Explored

### Approach A: `pendingOptimistic` slice on `ConversationState`

**Description:**
Add `Map<String, DmMessage> pendingOptimistic` (keyed by `pendingId`) to
`ConversationState`. `_onMessageSent` writes to `pendingOptimistic`
instead of mutating `messages`; `_onStarted`'s `emit.forEach.onData`
keeps replacing `messages` with the watch tick verbatim and never
touches `pendingOptimistic`. A derived
`List<DmMessage> get displayedMessages` projects `messages` ∪
`pendingOptimistic.values`, sorted by `createdAt` desc, with any
optimistic dropped whose corresponding rumor id is already present in
`messages`. UI consumers swap `state.messages` → `state.displayedMessages`.

**Layers affected:** BLoC, BLoC-state, Presentation (selector swap).

**Pros:**
- Clean separation: persisted truth vs. in-flight optimistic. Each side
  can be tested in isolation.
- Failure-strip is a one-line `pendingOptimistic.remove(pendingId)`; no
  list-walk through `messages`.
- Survives the same-event-arrives-via-watch case naturally — the
  projection drops the pending once its rumor id is in `messages`.
- Easy to migrate to Approach C later: when the durable-queue stream
  lands, `pendingOptimistic` becomes a derived view of `watchOutgoing`
  rather than per-bloc memory; the `displayedMessages` projection stays.

**Cons:**
- Adds state shape (`Map<String, DmMessage>` + getter + `copyWith`
  flag).
- Two places track "in-flight sends" until #3909 lands —
  `pendingOptimistic` in the bloc and `outgoing_dms` rows in the DB.
  They're consistent in this PR's scope but diverge if a later code
  path enqueues without going through this bloc.

**Risks / Unknowns:**
- All `BlocSelector<ConversationBloc, ConversationState, …>` and
  `BlocBuilder<ConversationBloc, …>` callsites that read
  `state.messages` need the audit. Single grep, ~3-5 callsites in the
  feature folder.
- Sort key collision on rapid sends: optimistic and persisted can share
  `createdAt` (second resolution). Tie-break by `id` (deterministic,
  irrelevant order between two rows with the same timestamp).

**Complexity:** Low.

### Approach B: merge inside `_onStarted`'s `onData`

**Description:**
Keep `state.messages` as the single message list. In the
`emit.forEach.onData` callback, preserve any "pending-marked" rows from
the prior `state.messages` and prepend them to the incoming watch tick.
Rely on `_onMessageSent`'s success/failure branches to strip the
optimistic explicitly after `sendMessage` returns. No state-shape
change.

**Layers affected:** BLoC only.

**Pros:**
- Smallest diff. State schema unchanged. UI unchanged.
- Reuses the existing pendingId convention (`startsWith('pending-')`).
- Easy to revert if Approach C ships sooner than expected.

**Cons:**
- Conflates "optimistic" and "persisted" in one list. Ordering becomes
  fragile if more than one optimistic is in flight (rapid sends): they
  must all be preserved and stripped independently.
- The strip in `_onMessageSent` success branch races with the watch
  tick that brings the persisted version. If the strip runs first,
  there's a short flicker where neither the optimistic nor the
  persisted is in `state.messages` (until the watch tick lands).
- Failure path strip already uses
  `state.messages.where((m) => m.id != pendingId)` — must continue to,
  and now also has to coexist with the merge in `onData`. Two places
  agree on the pending-id contract.
- Approach C rewrites the whole onData path anyway; B's merge logic
  gets replaced rather than reused.

**Risks / Unknowns:**
- A watch tick that emits the persisted version *with* the optimistic
  still in `state.messages` produces a duplicate bubble for a frame.
  The merge step needs a "drop optimistic if persisted with same
  content+sender+createdAt" rule, which is `hasMatchingMessage`-shaped
  but client-side. Not hard, but an opportunity for off-by-one.

**Complexity:** Low (smaller LoC than A) but slightly higher cognitive
complexity per change.

### Approach C: `Rx.combineLatest2(watchMessages, watchOutgoing)` at the repository layer

**Description:**
Promote the merge from BLoC to `DmRepository.watchMessages`. The new
`watchMessages(conversationId)` returns a stream that combines
`directMessagesDao.watchMessagesForConversation(...)` with
`outgoingDmsDao.watchForConversation(...)`, mapping each `OutgoingDm` to
a `DmMessage` (with a "pending"/"sent"/"failed"/"sentPartial"
delivery-status) and the persisted rows to `delivered`. The bloc no
longer maintains an in-memory optimistic; it just renders what the
repository hands it. Status-aware bubble UI (clock / single check /
double check / error) follows.

**Layers affected:** Repository, BLoC (simplified), Presentation
(bubble + delivery-status indicators).

**Pros:**
- This is the architectural fix. After it lands, optimistic state is
  durable across app kill, signer drops, and BlocProvider recreates,
  not just visible-while-bloc-alive.
- Subsumes the partial-delivery state machine cleanly: a
  `selfWrap_status: failed` `OutgoingDm` row is a `sentPartial`
  delivery-status on the displayed message.
- Eliminates the entire pending-id convention. No more `pending-` id
  prefixes in code or tests.

**Cons:**
- Significant scope. Touches `DmRepository`, `ConversationBloc`,
  `MessageBubble` (or a new wrapper widget), state shape, the
  retry-on-fail SnackBar wiring, the Drift watch fan-in, and the
  delivery-status enum.
- Designed and reserved for #3909. Shipping it in #4193's PR scopes
  out of bug-fix into feature. Per `agent_workflow.md` §4, that's a
  scope-creep red flag.
- Tests for the delivery-status enum, the merged stream's ordering,
  per-recipient group-DM status, and bubble indicators are a much
  larger surface than the bug needs.
- Requires `MessageBubble` extension or wrapper, which crosses into
  `divine_ui` (strict-coverage gate — every new public method needs a
  matching test in the same PR).

**Risks / Unknowns:**
- Group-DM partial-delivery UX is named in #3912's "future hardening"
  bullet as out of scope for the current children. Shipping C without
  group-DM status would either be inconsistent or expand again.
- The `OutgoingDm → DmMessage` mapping with status assumes a stable
  delivery-status enum that survives schema versioning — the
  `OutgoingWrapStatus` (`pending` | `sent` | `failed`) does NOT map
  cleanly to a per-DmMessage status without combining
  `recipient_wrap_status` and `self_wrap_status`. The combined enum is
  designed in #3909 but not yet pinned.

**Complexity:** High.

### Approach D: persist optimistic into `direct_messages` immediately

**Description:**
Have `DmRepository.sendMessage` insert into `direct_messages` upfront
with a synthetic id (e.g. the rumor id, since rumor.id is computed
before publish in the post-#3911 flow), publish, then update the row's
delivery state on outcome. The watch stream becomes the only source of
truth — the bloc has no optimistic logic at all.

**Layers affected:** Repository, schema (delivery-status column on
`direct_messages`), BLoC (simplified).

**Pros:**
- Simplest mental model: every visible message lives in
  `direct_messages`.
- Survives app kill mid-send for free (the row exists).

**Cons:**
- Schema change on `direct_messages` (add a delivery-status / pending
  column). `outgoing_dms` was added precisely to avoid touching the
  `direct_messages` schema for in-flight rows — see #3911's design
  rationale ("durable retry queue without polluting the persisted-
  message table").
- Inbound `_handleGiftWrapEvent` dedups by `gift_wrap_id` and
  `hasMatchingMessage`. A pre-publish insert would have neither real
  gift-wrap id nor real createdAt, breaking the dedup window when the
  self-wrap returns.
- Duplicates the `outgoing_dms` work in a different table. Two
  competing in-flight states.
- Conflicts with #3909's "outgoing_dms is the queue" architecture.

**Risks / Unknowns:**
- Schema migration on existing installs. Drift schema version bump.
- Rolling back a "pending" row on send failure means deleting from
  `direct_messages`, which has historically only been the receive
  path's responsibility (modulo soft-delete via NIP-09 kind 5).

**Complexity:** Medium-to-high, with high architecture-misalignment
cost.

## Recommendation

**Approach A (`pendingOptimistic` state slice).**

Architecturally it sits cleanly between today's fragile in-memory
optimistic and tomorrow's `Rx.combineLatest2`-based source-of-truth in
#3909:

- **vs. B:** A's separate slice is more discoverable, easier to test,
  and survives concurrent in-flight sends without ad-hoc id-prefix
  filtering inside `onData`. Slightly larger diff but materially less
  cognitive load on every future change.
- **vs. C:** A is bug-scoped. C is the right destination but tripling
  the PR for a user-visible-bug fix violates `agent_workflow.md` §4.
  When #3909 lands, A's `pendingOptimistic` slice maps 1:1 to the
  derived view of the merged stream — the UI keeps reading
  `state.displayedMessages` and the bloc body shrinks.
- **vs. D:** A doesn't touch the `direct_messages` schema or the
  `_handleGiftWrapEvent` dedup contract. D opposes the design rationale
  that justified `outgoing_dms` in the first place (#3911 PR body).

A also gives us the test seam the existing suite is missing: a
`StreamController<List<DmMessage>>` for `watchMessages` that lets us
push an empty tick mid-send and pin "the optimistic survives." That
test is independent of which approach lands, and writing it during A
locks the contract in place for C's eventual rewrite.

## Open Questions for /plan

- [ ] Audit every `state.messages` reader (`Grep state.messages` inside
  `mobile/lib/screens/inbox/conversation/` plus any test that
  constructs a `ConversationState` directly) and decide which need to
  swap to `state.displayedMessages`. Specifically, does
  `ConversationView`'s `_ConversationContent` selector need to migrate?
  Tests certainly do.
- [ ] On `SendStatus.sentPartial`, does `pendingOptimistic` get
  stripped? **Tentative answer:** yes — the persisted row IS in
  `direct_messages` for sentPartial (only the self-wrap publish failed,
  not the persistence), so the watch tick will bring the real row and
  the projection will drop the pending once its corresponding rumor id
  appears in `messages`. Pin this in a test.
- [ ] Tie-break sort when optimistic and persisted share `createdAt`:
  `id` ascending? The pending row's id is `pending-<uuid>` and the
  persisted's is the rumor id (64-char hex). Lex sort puts pending
  after the persisted when both share `createdAt`, which is fine.
- [ ] Does the failure path also clear `lastFailedSend`'s coupling to
  `messages`? In the current code, the failure emit strips by id-walk
  on `state.messages` (lines 178-181 of `conversation_bloc.dart`).
  After A, the optimistic was never in `state.messages`, so the strip
  becomes `pendingOptimistic.remove(pendingId)` and the failure-emit
  `messages: state.messages` stays as-is.
- [ ] Should `displayedMessages` be a getter or a stored field? Per
  `state_management.md` "Getters vs Stored State", lists are an
  expensive-derivation case. But for a typical conversation
  (~hundreds of messages, single-digit pendings), the merge + sort is
  cheap enough that a getter beats the bookkeeping. Pin a stress-test
  with N=1000 messages + 1 pending if there's any doubt.
- [ ] State shape change → the `conversation_bloc_test.dart` baselines
  on `ConversationState()` const need an updated default for
  `pendingOptimistic` (empty `const {}`).

## Prerequisites

- [ ] None blocking. No design/Figma needed (no UI surface change).
  No protocol decisions. No new packages.
- [ ] Optional: confirm with the reporter that the Android device was
  using Keycast RPC vs. a local nsec, since that calibrates how big the
  send-window actually is in practice. Not required to ship A — the
  fix is correct regardless of signer.

## Next Step

`/plan https://github.com/divinevideo/divine-mobile/issues/4193` —
proceed to implementation planning targeting Approach A. The plan
should include the new
`StreamController<List<DmMessage>>`-based test as a hard requirement,
and call out the `state.messages` → `state.displayedMessages`
read-site audit.
