# Brainstorm: recovering group conversations erased by the startup dedup pass (#8407)

Date: 2026-08-31
Seeded by: `tasks/findings_8407.md` (5 investigation rounds, 6 executed reproductions)

## Problem Statement

A startup pass deleted from `main` today (#8401) had, since 2026-04-04, folded any group
DM conversation into the 1:1 sharing its alphabetically-first peer: it re-parented the
group's messages onto the 1:1 and deleted the group row. Prevention has landed; the
damaged data has not been repaired. The question is whether — and how — to repair it.

**The investigation changed the question.** #8407 frames this as data archaeology. It is
actually a **live routing defect**: because nothing recreates a group row, an affected
room stays permanently forked and every new message from a third member spawns another
orphan 1:1 (findings R5.2).

## Constraints

- **No out-of-band repair.** The on-device DB is SQLCipher-encrypted (R4.1), so any pass
  runs in-app through Drift, and the population cannot be counted by dumping devices.
- **Layered architecture** — this is repository/data-layer work in `dm_repository` +
  `db_client`; no UI layer required for the repair itself.
- **NIP-17 is explicit**: "The set of `pubkey` + `p` tags defines a chat room. If a new
  `p` tag is added or a current one is removed, a new room is created."
- **#7811 tombstones** must not be resurrected (cheap guard; R3.2).
- **#2740 is a real, user-reported bug** — the "phantom group" #2741 was written to kill.
- **Group chat UI is essentially unbuilt** (#5586 open); a restored group row lands in a
  product surface that barely supports it.

## Prior Art

- #2118 (2026-03-11) NIP-17 data layer — the 24-day origination window opens.
- #2740 / #2741 (2026-04-04) — collapse guard **and** destructive pass, same commit.
- #5478 — sender-count discriminator, **never merged**, and refuted by REPRO D.
- #8203 / #8270 / #8401 — the prevention half.
- #7811 — removal tombstones.

## Established by execution (not assumption)

| Fact | Evidence |
|---|---|
| The pass deletes the group row and re-parents its messages | REPRO A |
| `tags_json` survives, write-once since schema v1, never updated | REPRO B + R4.5 |
| `participants = p_tags ∪ senderPubkey` | REPRO B + NIP-17 verbatim |
| Damage is locally detectable with no false positives | REPRO E |
| A real group with a **silent** member is byte-identical to a mention-inflated 1:1 | REPRO C ≡ REPRO D |
| The `e` tag separates the *documented* mention case | REPRO F |
| Affected rooms fork permanently and cannot self-heal | R5.2 |

## Approaches Explored

### Approach A: Close as won't-fix

Accept the loss. Prevention has landed; the population is closed (no new group rows can
originate — R3.4) and shrinking (logout/account-switch hard-deletes the evidence — R1.5).

**Layers:** none.
**Pros:** zero risk, zero cost, no chance of regressing #2740.
**Cons:** leaves the **ongoing** defect of R5.2 — affected rooms keep misrouting replies
and keep spawning orphan 1:1s. "It only affects a few users" is an assumption we cannot
currently measure.
**Complexity:** none.

### Approach B: Spec-faithful full restore

For every 2-participant conversation, group its messages by reconstructed participant set
and recreate a conversation row for each set larger than the declared one, moving those
messages back. Follows NIP-17 literally.

**Layers:** Repository (`dm_repository`), Client (`db_client` DAO).
**Pros:** protocol-correct; deterministic, no heuristics; repairs **future** routing
because `existingFull != null` starts matching again; smallest amount of judgement in
code.
**Cons:** reintroduces #2740 — every mention-inflated thread reappears as a separate
room, which is the exact complaint that motivated the pass. Needs a product decision.
**Complexity:** Medium.

### Approach C: Conservative restore — only positively-attested rooms

Same detection, but restore a room only when it is positively attested as a real group:
**≥2 distinct senders** within the reconstructed set, **or** the `e`-tag test (REPRO F)
says the widening is not a reply-mention. Leave everything ambiguous exactly as it is.

**Layers:** Repository, Client.
**Pros:** cannot resurrect a documented mention-phantom, so it **does not need the product
decision to proceed**; repairs the clear-cut rooms including their future routing;
strictly improves on today for the cases it touches and changes nothing for the rest.
**Cons:** silently misses a real group whose extra member never spoke (REPRO D) — those
stay broken; more code and more test surface than B; it is a heuristic, and heuristics
need documenting.
**Complexity:** Medium-High.

### Approach D: Detect and ask the user

Ship only the detection (REPRO E) plus an affordance: "this thread contains messages
involving N other people — restore the group?"

**Layers:** UI, BLoC, Repository, Client.
**Pros:** the user holds the ground truth the code cannot derive; never makes a wrong
automatic call; fits #7811's spirit of not deciding removal/restoration for the user.
**Cons:** most expensive; asks users to adjudicate a protocol subtlety they have no
context for; lands in a group-chat surface that is barely built (#5586); a prompt on
launch about old threads is poor UX.
**Complexity:** High.

### Approach E (rejected): fix forward and let re-ingest rebuild

Make `_resolveConversationParticipants` NIP-17-compliant and let relay re-ingest rebuild
rooms. Rejected as a *recovery* strategy: it is bounded by the DM subscription's `since`
window, requires the room to still be active, and the re-ingest path is **currently
degraded** by a separate NIP-01 violation found live (R4.2). It is really #5586's scope,
and it is orthogonal to repairing already-damaged local state.

## Recommendation

**Approach C**, for one decisive reason: it is the only option that **strictly improves
matters without requiring the unresolvable product decision**.

The investigation established that no *total* discriminator exists (REPRO C ≡ REPRO D), so
B and D both bottom out in "does Divine follow NIP-17 or keep #2741's override?" — a
product call. C sidesteps it by only acting where the evidence is unambiguous, and by
leaving the ambiguous remainder in exactly its current state. It converts a blocking
product decision into a non-blocking one about the residual set.

C also captures the value R5.2 identified: for every room it restores, it repairs future
routing, not just history.

If the product answer later turns out to be "follow NIP-17", C's detection and
reconstruction code is exactly what B needs — C is a strict subset of B, not a detour.

## Open Questions for /plan

- [ ] Where does the pass run? (post-auth maintenance is where the damage came from; a
      one-shot migration keyed on a stored flag is safer than a per-launch pass)
- [ ] One-shot vs idempotent-per-launch, and how the "already run" marker is stored.
- [ ] Exact attestation predicate and where it lives (repository vs a small pure helper
      that can be unit-tested without a DB).
- [ ] Reading soft-deleted rows: `getMessagesForConversation` filters `isDeleted` (R1.6),
      so recovery needs a raw read.
- [ ] Canonicalise participant sets as a sorted join — Dart `Set` has no value equality
      (R3.1), which already broke one version of the detection query.
- [ ] Does the restored row need `subject` (newest wins, per NIP-17) and a sensible
      `lastMessageTimestamp` / read state?
- [ ] Should the pass emit a counter so the population finally becomes measurable?

## Prerequisites

- [ ] **Product decision on the residual ambiguous set** — needed for B/D, NOT for C.
- [ ] Decide whether the separately-found NIP-01 subscription-id bug (R4.2) is filed and
      fixed independently — it is out of #8407's scope but degrades the re-ingest route.

## Next Step

`/plan 8407` targeting Approach C.
