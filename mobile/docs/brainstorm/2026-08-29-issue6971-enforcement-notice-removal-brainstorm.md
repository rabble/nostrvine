# Brainstorm: Removing an enforcement notice from Message Requests (#6971)

Date: 2026-08-29

Seeded with `tasks/findings_6971.md` (nine hypotheses, device-verified).
Direction chosen by the requester before Phase 2: **D+ — drop the destructive
action for moderation identities and fix the bulk sweep.**

## Problem Statement

A retired-moderation-key enforcement notice lands in Message Requests, where the
preview frames it as "Divine Moderation wants to message you" and offers
"Decline and remove". One unconfirmed tap erases it permanently, and it is the
only place a user can read *why* they were actioned. We need to decide what that
action should do for an official identity, without reintroducing friction the
team deliberately removed.

## Constraints

- **Layered flow.** `isModerationAccount` is app-layer config
  (`lib/config/official_accounts.dart`). `dm_repository` is a package and must
  not learn Divine's moderation identity — the reason `DmSendPolicy` is an
  injected typedef (#6963). Any new policy follows the same injection rule.
- **#8090 counter-precedent.** PR #8090 (2026-08-24) removed the Block button
  *and its confirmation sheet* from this exact file. Adding a confirmation here
  contradicts a five-day-old decision by this issue's assignee. Removing UI does
  not.
- **#8076 gate.** The consent-first inbox epic states "Official messages never
  enter Message requests or Likely spam" and marks operational Divine accounts
  not blockable, but carries an explicit "do not begin production work" gate.
  Anything shipped now must not foreclose that direction.
- **#6963 position.** Removal "deletes the user's own local copy and is their
  call" — the standing argument *against* taking the action away.
- No new ARB keys if avoidable: 22 locales, and #8206 is concurrently touching
  `app_en.arb` (key-level union merge risk).
- BLoC-first; constructor injection; no widget helper methods returning `Widget`.

## Prior Art

- `#6963` / `ef4257f23` — labelled retired threads, closed the dead composer,
  added `isRetiredModerationAccount`. Established the injected-predicate pattern.
- `#7916` / `6bf31ba0c` — added a Block button with a `VineBottomSheet`
  confirmation to this screen.
- `#8090` / `23b779c4c` — reverted that Block button and its confirmation.
- `ConversationListBloc` already takes `DmPeerAccountPredicate`
  (`conversation_list_bloc.dart:25`) for exactly this kind of policy.
- `RequestPreviewCubit` already takes injected `bool Function(String)`
  predicates (`_isApprovedRecipient`), so the pattern exists in the same feature.

## Structural findings that shaped the options

Three facts discovered in Phase 1/2 that constrain any implementation:

1. **Removal is triply irreversible.** The tombstone is only one of three
   mechanisms. `removeConversation` does *not* clear `processed_gift_wraps`, so a
   re-delivered wrap is skipped as already-seen; and the live subscription asks
   for `since: newestSyncedAt - 2 days`, so an older notice is never re-requested
   at all. This is what killed the original "archive by skipping the tombstone"
   direction — removing the tombstone alone changes nothing observable.
2. **The preview has an unresolved state with no peer.**
   `_UnresolvedRequestScaffold` renders the decline button with no counterparty
   (`request_preview_view.dart:209`), used for `loading` and `_LoadFailedMessage`.
   A conversation id is a SHA-256 of sorted participants, so the peer cannot be
   recovered from it, and a cold deep link carries no `extra`. **A UI-only gate
   therefore cannot cover every state.**
3. **`RequestPreviewPage` does not provide `ConversationListBloc`**, so the
   preview cannot read a per-row moderation flag off the list bloc. The bulk
   sweep can — `MessageRequestsView` does have it in scope.

## Approaches Explored

### Approach A: UI-only gate

**Description:** In the resolved state, omit `_DeclineAndRemoveButton` when
`isModerationAccount(otherPubkey)`. In `MessageRequestsView._showBulkActions`,
filter the id list by the same predicate before calling `removeAllRequests`.

**Layers affected:** UI only.

**Pros:**
- Smallest possible diff; two files, no new dependencies, no ARB keys.
- `RequestPreviewState` already carries `participantPubkeys`, so the resolved
  state needs no new plumbing.
- Trivially covered by widget tests.

**Cons:**
- Leaves finding (2) open: the loading and load-failed states still render a live
  destructive button with no peer to test against.
- Puts a policy decision in two widget files. A third entry point added later
  misses it silently — the same shape as the original #6416 defect, where
  `isModerationAccount` reached one surface out of five.

**Risks / Unknowns:** the residual hole is narrow (cold deep link whose preview
read fails) but it is exactly the path a notification tap takes.

**Complexity:** Low.

### Approach B: Cubit chokepoint + UI gate (defence in depth)

**Description:** Inject `DmPeerAccountPredicate` into
`MessageRequestActionsCubit`. `declineRequest` resolves the conversation via
`DmRepository.getConversation` (already exists, `dm_repository.dart:6159`) and
refuses when any participant is a moderation identity, reporting a distinct
outcome rather than a silent no-op. `removeAllRequests` filters the same way, so
the sweep is correct regardless of what the caller passed. The UI additionally
hides the button in the resolved state, so the refusal is the backstop rather
than the user-visible mechanism.

**Layers affected:** UI + BLoC/Cubit. Repository unchanged (read-only use of an
existing method).

**Pros:**
- Closes finding (2): the cubit resolves the peer even when the UI could not, so
  the loading/load-failed hole cannot destroy a notice.
- One chokepoint. Every current and future decline path goes through
  `declineRequest`/`removeAllRequests`; a new entry point inherits the rule.
- Reuses the existing `DmPeerAccountPredicate` typedef and the injection pattern
  #6963 established. No package API churn, no Divine policy inside
  `dm_repository`.
- Filtering the sweep in the cubit rather than the view means the view keeps
  passing "all requests" and cannot drift.

**Cons:**
- `declineRequest` gains an await before the delete. Callers already consume its
  `bool` result (`request_preview_view.dart:526`), so the shape absorbs it, but
  the refusal needs its own status so the UI does not report a generic failure.
- Slightly more surface to test than A.

**Risks / Unknowns:** if the conversation row is already gone,
`getConversation` returns null — must fail *open* (allow the removal) rather
than stranding an undeletable row.

**Complexity:** Low-Medium.

### Approach C: A `DmRemovePolicy` typedef in `dm_repository`

**Description:** Mirror `DmSendPolicy` with a removal policy injected into
`DmRepository`, consulted inside `removeConversation`/`removeConversations`.

**Layers affected:** Repository package + app wiring.

**Pros:**
- Highest fidelity to the #6963 precedent; the rule holds for *every* caller
  including the inbox long-press path.
- Symmetric with the send gate, so the two policies read as a pair.

**Cons:**
- New package API surface for a rule with two call sites. `DmSendPolicy` earned
  its seam because sending happens from queue drains, deep links and
  share-to-DM; removal does not have that spread.
- Extends the rule to the *inbox* removal path, which is a behaviour change
  nobody asked for and which #6963 explicitly left as the user's call.
- Package-level change drags `videos_repository`-style coverage obligations and a
  wider blast radius for a two-widget problem.

**Complexity:** Medium. Rejected on YAGNI.

## Recommendation

**Approach B.** It is the only option that closes the unresolved-state hole
found in Phase 2, and it does so without inventing a seam. It reuses a typedef
and an injection pattern that already exist in this feature, touches no package
API, adds no ARB keys, and — because it *removes* a control rather than adding a
confirmation — it does not collide with #8090. It also leaves #8076 free: if
official identities are later routed out of Requests entirely, the cubit guard
becomes dead code to delete rather than a design to unwind.

Approach A is the same user-visible behaviour for less work, but it reproduces
the exact failure shape that caused #6416 — a policy applied at some surfaces and
not others. Approach C is the right answer to a bigger question nobody has asked.

## Open Questions for /plan

- [ ] What should the preview show in place of the removed button — "View
      messages" alone, or does the action bar need a non-destructive secondary?
      (Leaning: alone. No new copy, and the tile already says "This conversation
      is closed.")
- [ ] Should the guard key on `isModerationAccount` (current + retired) or only
      `isRetiredModerationAccount`? Current-key notices are pinned out of
      Requests today, so the broader predicate is free insurance and survives the
      next rotation. Confirm that reading.
- [ ] Refusal outcome shape: a new `MessageRequestActionsStatus` value, or reuse
      the existing `bool` return with no snackbar? Must not surface
      `commonSomethingWentWrong` for a deliberate refusal.
- [ ] Does `removeAllRequests` need to report that it skipped rows, or is a
      silent skip correct? (Leaning: silent — the sweep already promises "all
      requests" loosely and the row visibly remains.)
- [ ] Group conversations: `participantPubkeys` can hold more than one peer. Guard
      if *any* participant is a moderation identity.

## Prerequisites

- [ ] None blocking. No Figma, no new package, no protocol decision.
- [ ] Worth noting in the PR: this is the mechanical half of #6971. The copy
      questions ("wants to message you" on an enforcement notice; whether the
      reason should live somewhere durable) stay with the assignee.
- [ ] `tasks/findings_6971.md` H8 remains open — the guard is correct whether the
      affected population is zero or not, so it does not block.

## Next Step

`/plan 6971` — implement Approach B, scoped to the mechanical half only.
