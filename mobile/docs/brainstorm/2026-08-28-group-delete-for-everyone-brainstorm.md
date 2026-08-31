# Brainstorm: group delete-for-everyone reaches only one recipient (#8188)

Date: 2026-08-28

## Problem Statement

Deleting a group DM "for everyone" silently no-ops for every recipient except
one. `sendGroupMessage` builds a **distinct rumor per recipient**, so recipient
*i* stores the message under rumor id *i*; the sender persists exactly one row
(keyed to the first live success) and `deleteMessageForEveryone` emits a single
`['e', <that one id>]`. Recipients 2..N look up an id they have never seen and
apply nothing. The sender's UI shows the bubble gone and the retraction is
confirmed on the wire, so nothing surfaces the failure.

## Constraints

- Layered flow `UI -> BLoC/Cubit -> Repository -> Client`; this change lives
  entirely in the repository layer (`mobile/packages/dm_repository`).
- `dm_repository` and `db_client` are pure-Dart packages under the workspace;
  `db_client` carries a Drift schema with a migration test, so any schema change
  is a real migration plus a regenerated snapshot.
- NIP-17 / NIP-59 / NIP-09 govern the wire format; the kind-5 travels
  gift-wrapped, so the relay never sees it.
- No technical debt, no skipped tests; every new behaviour needs a test that can
  fail (`.claude/rules/testing.md`).

## Prior Art

- **#8174** (`cbba859b7`) — receive half: `_routeWrappedDeletion` applies wrapped
  kind-5 deletions and is **conjunct** across `e` tags.
- **#8184** (`4fcd18016`) — sender half for 1:1: delete-for-everyone became a
  wrapped, durable NIP-17 rumor. The group case was split out to #8188.
- **#8164**, **#8232** — concurrency and blocked-policy handling on the same path.
- **#6046** — the same-second sibling-id collision that introduced the durable
  `sendBatchId` token.
- `divine-web/src/lib/dm.ts` — the first-party web client, which **already**
  builds one rumor per group send and wraps it N times.

## Findings that shaped the exploration

The four findings that changed the answer:

1. **The issue's stated mechanism is wrong.** Siblings do not differ by their
   p-tag *set* — the set is identical; only the *order* differs, because
   `buildRumor` prepends `['p', <addressee>]`. A NIP-01 id hashes the tags
   *array*, so the rotation alone forks the ids. Measured: rotated -> 3 ids,
   canonical -> 1 id.
2. **"No receive-side change" is false.** `_routeWrappedDeletion` downgrades the
   whole wrap to `deferred` if *any* `e` tag fails to resolve, and `deferred`
   wraps are deliberately never ledgered. A group recipient can never hold the
   other N-1 sibling ids, so a multi-`e` deletion would be deferred **forever**,
   on every recipient, and re-decrypted on every later drain.
3. **Every working group-DM client emits ONE shared rumor** — Amethyst (the NIP
   author's reference client, whose source says *"every seal encodes the same
   rumor id. This anchors cross-recipient dedupe + reaction/receipt targeting on
   group sends"*), 0xchat, Coracle/Flotilla (`// Stabilize the event id across
   the different wraps`), Nostrudel. Nobody sorts tags; they all reuse one rumor
   object. NIP-59 says it outright: *"a **single** rumor may be wrapped and
   addressed for each recipient individually"* (`59.md:108`).
4. **The breakage is one-directional and it is ours.** Inbound group messages
   already carry one id, so our receive path is fine. Only our *sends* are
   unaddressable by peers — and by our own web client.

## Approaches Explored

### Approach A: multi-`e` deletion (the issue's suggestion)

**Description:** Retain the sibling rumor ids at send time and emit one `e` tag
per sibling on the deletion.

**Layers affected:** Repository.

**Pros:**
- Small sender-side diff; spec-legal (NIP-09 permits "one or more" `e` tags).
- The receive half genuinely does iterate all `e` tags.

**Cons:**
- **Permanently defers every group deletion on every recipient** (finding 2).
  Not a correctness bug, but an unbounded background-work leak feeding a set
  that is already an open follow-up from #8174.
- Compensates for the divergence instead of removing it; leaves group reactions
  and reply threading broken.

**Complexity:** Low — and wrong.

### Approach A': multi-`e` plus a receive-side rule change

**Description:** As A, but relax the conjunct rule so a deletion is `processed`
once at least one named target resolves.

**Pros:** Keeps the issue's payload shape.

**Cons:**
- Breaks the case #8174 was written for: a deletion naming a target that has
  genuinely not synced yet would be cemented and lost.
- NIP-09 requires per-`e` authorship validation (`09.md:31`), which a client
  cannot perform for an event it does not hold — so "treat unknown ids as done"
  is not obviously safe.

**Complexity:** Medium, with a real regression risk.

### Approach B: one deletion rumor per recipient

**Description:** Build N deletion rumors, each naming only that recipient's
sibling id. Sibling ids are recoverable without new storage (the persisted row
already carries content, `createdAt`, all recipients in original order,
`messageKind` and `sendBatchId` — the full preimage).

**Pros:**
- No deferred pollution; each recipient's deletion resolves and is ledgered.
- No schema change if the ids are recomputed.

**Cons:**
- `markMessageDeletionPending` stores exactly one `deletionRumorJson` for the
  retry sweep, so N deletions need storage or deterministic rebuild.
- Fixes only deletion. Group reactions and reply threading stay broken, and the
  sender's second device stays broken.
- Entrenches the divergence from every other client.

**Complexity:** Medium.

### Approach C: canonical rumor with an `outgoing_dms` PK migration

**Description:** Emit one byte-identical rumor per group send; change the queue
PK from `{id}` to `{id, recipientPubkey}` so N sibling rows can coexist.

**Pros:** Removes the root cause; fixes deletion, reactions, replies and the
sender's second device at once.

**Cons:**
- Drift PK migration v11 -> v12, plus schema dump and migration test.
- ~31 production call sites and 14 test files on the outgoing-DM id surface.
- **Silent-failure trap:** `_joinOrStartRecovery` is keyed `'full:${rumor.id}'`.
  With a shared id, siblings 2..N join sibling 1's in-flight future instead of
  publishing — a group send would reach one recipient.

**Complexity:** High.

### Approach C': canonical rumor with a per-recipient surrogate queue handle — **CHOSEN**

**Description:** Build the rumor **once** per group send (all recipients as `p`
tags, stable order) and hand that same rumor to every wrap — exactly what
`divine-web`'s `createRecipientGiftWraps` does today, and what
`_fanOutDeletion` already does for deletions. Give each queue row a
per-recipient handle in the existing single-column `id` so the queue, the retry
sweep and the UI's sibling aggregation keep working unchanged.

**Layers affected:** Repository only (`dm_repository`), plus doc comments in
`db_client`.

**Pros:**
- **No schema migration.** Verified: `recoverFullSend` already treats its
  `rumorId` argument as an opaque queue handle (the rumor comes from
  `row.rumorEventJson`, the recipient from `row.recipientPubkey`); nothing
  validates the format of `outgoing_dms.id`; recovery resolves the row through
  the opaque handle for either a full-send retry or a self-wrap-only retry.
- **`deleteMessageForEveryone` needs zero changes** — its existing single `e`
  tag becomes correct automatically.
- **The receive path needs zero changes** — a recipient already stores under
  `rumor.id`.
- Dissolves C's two traps: the lock key and the UI map are keyed on the
  surrogate, so both stay unique.
- Fixes group reactions cross-visibility and group reply threading, which share
  the same root.
- Brings mobile in line with divine-web, Amethyst, 0xchat, Coracle and NIP-59.
- Removes the per-recipient rumor loop rather than adding machinery.

**Cons / risks:**
- `outgoing_dms.id`'s documented invariant changes for group rows; existing rows
  keep plain ids, so the keyspace is mixed (disjoint by separator, the same
  precedent `_batchKeyOf` already relies on). Every doc comment must be corrected.
- 1:1 sends keep the plain rumor id, so the surrogate is group-only — an
  asymmetry that must be explicit and tested.
- `_finalizeAfterRecipient*` and the cancel interlock currently pass
  `rumors[i].id`; each must pass the surrogate. Missing one silently finalizes
  the wrong row.
- Forward-only: group messages already sent keep per-recipient ids and stay
  undeletable-for-everyone. Accepted and to be documented.
- A future per-recipient element in a `p` tag (e.g. a relay hint) would re-fork
  the ids. Amethyst avoids this by putting hints on the gift wrap's `p` tag.
  Guarded by an explicit test rather than convention.

**Complexity:** Medium.

## Recommendation

**Approach C'.** It removes the cause rather than compensating for it, needs no
migration, leaves the deletion and receive paths untouched, and converges four
first- and third-party clients on one rumor identity. Inspired directly by
divine-web's current behaviour, and independently corroborated by the NIP-59
text and by every shipping group-DM client surveyed.

Deliberately **not** in scope:
- Changing whether the sender appears in the rumor's `p` tags. mobile excludes
  the sender, matching Amethyst; divine-web and 0xchat include it. Both are
  tolerated everywhere (room keys are Sets in every client). Recorded, not acted on.
- The sender's own second device persisting a different sibling id. C' fixes it
  inherently for new sends; no extra work is planned for it.

## Open Questions for /plan

- [ ] Exact surrogate handle format for group queue rows, and how 1:1 stays on
      the plain rumor id.
- [ ] Every call site that currently passes `rumors[i].id` and must pass the
      surrogate (cancel interlock, `_finalizeAfterRecipient*`, `_stampQueuedRow`).
- [ ] Whether `buildRumor` gains a group-shaped entry point or `sendGroupMessage`
      assembles the tags and calls it once.
- [ ] Shape of the 3-party real-socket test against the `fake_relay` harness.
- [ ] Which existing group-send tests assert per-sibling ids and must be updated.

## Prerequisites

- [x] Worktree from `origin/main` — `.worktrees/8188-group-delete`,
      branch `fix/8188-group-delete-canonical-rumor`, base `7732e48ce`.
- [x] Correction comment posted on #8188.
- [ ] None outstanding; no design or protocol decision is blocked.

## Next Step

`/plan 8188` — implementation plan against this direction.
