# Brainstorm: #7683 — degenerate participant sets in `classifyPotentialRequests`

Date: 2026-09-06
Seeded by: `tasks/findings_7683.md` (7 investigation rounds)
Issue: https://github.com/divinevideo/divine-mobile/issues/7683 · Epic: #8229

## Problem Statement

#7683 asks to remove a "redundant" `otherPubkeys.isEmpty` early-return guard in
`DmRepository.classifyPotentialRequests`. **That guard does not exist and never did.** Full git
history shows the empty check was always a disjunct inside one `if` (introduced #2219, unchanged
through #5387) and was **deleted by #6294 — the very PR the issue cites as its context**. The
issue's literal ask is a no-op.

Underneath it sit two real, verified residuals: the empty-participant route to the inbox is now
implicit/undocumented/untested vacuous truth, and the self-filter is case-sensitive against a
documented in-repo convention that it should not be.

## Constraints

- Layered architecture; this is a pure static method in the Repository layer — no UI/BLoC change.
- `.claude/rules/testing.md`: a test must be able to fail for a real reason.
- Epic #8229 success criterion: *"a DM docstring is evidence of what the code does."*
- `dm_repository_test.dart` sits at **14** in `mobile/scripts/baseline/shared_setup_stubs.txt` — a
  ceiling that may only shrink, so any new stub must go in a leaf group.
- `tasks/lessons.md` (#5374): do not ship a fix whose premise is an unobservable on-device value.
- Report-only on GitHub until explicitly authorized.

## Prior Art

- `mobile/lib/blocs/dm/minor_dm_approval.dart` — `allParticipantsApprovedForMinor`: the exact
  structural twin, which **guards `isNotEmpty` and documents why**, naming `[].every(...)`.
- `conversation_bloc.dart:405,410` and `inline_reel_reply_cubit.dart:77,79` — the same
  `isNotEmpty && every(...)` idiom, four more times.
- `_isSelf` (`dm_repository.dart:8961`) + `pubkeysEqual` — the case-insensitive self-compare and the
  dartdoc explaining why exact `==` is wrong.
- #8261 (closed) — Divine does **not** support self-addressed conversations. #8351 shipped the
  send-side refusal.
- `tasks/lessons.md` #5374 — a prior wrong-theory fix on this same function.

## Approaches Explored

### Approach A: Inline `isNotEmpty` guard + case-insensitive self-filter  ← RECOMMENDED
**Description:** At L7632 compare self case-insensitively; at L7641 guard the vacuous `every()`.
Document both in the dartdoc, citing #8261 and #6294. Add regression tests.
**Layers affected:** Repository only.
**Pros:** Matches the idiom already used at four DM sites. ~2 lines. Correct whether or not the
state is reachable, so it does not rest on the 0.97 H3 claim. A degenerate row now routes to
`requests`, which passes through the existing `_classifyDiagnostics` branch and **logs itself for
free** — the diagnostic `lessons.md` recommends, at zero cost.
**Cons:** Changes behaviour for a state believed unreachable. `isNotEmpty &&` is terser than prose.
**Risks:** If a degenerate row *is* reachable, its thread moves inbox → requests. Under #8261 that
is the more correct destination, and quieter.
**Complexity:** Low.

### Approach B: Extract a shared `allParticipantsFollowed` predicate
**Description:** Mirror `minor_dm_approval.dart` exactly — a small file with a documented predicate,
called from classify.
**Pros:** Follows the closest structural precedent. Directly unit-testable without constructing
conversations.
**Cons:** **Only one call site exists.** Speculative reuse; YAGNI.
**Complexity:** Low–Medium.

### Approach C: Explicit `if (otherPubkeys.isEmpty)` branch
**Description:** Restore #2219's explicit shape with the opposite destination and an #8261 comment.
**Pros:** Most self-documenting.
**Cons:** A dedicated branch implies the case is expected; a guard reads more honestly for a state
that should not occur. More lines for identical behaviour.
**Complexity:** Low.

### Approach D: Normalize pubkey case at ingest/storage
**Description:** Lowercase pubkeys in `_extractParticipants` and on write, killing the H4a class.
**Pros:** Root-cause rather than per-site.
**Cons:** **`computeConversationId` is case-sensitive**, so normalizing changes ids for any existing
mixed-case row — splitting or merging threads and requiring a Drift migration. All of it for a
defect scored **0.10 reachable**. This is the #5478 mistake `lessons.md` records: a wide fix on an
unobservable premise.
**Complexity:** High. **Rejected.**

## Recommendation

**Approach A**, adopting C's comment discipline in the dartdoc. Rationale: smallest change that is
correct independent of the reachability question, matches an idiom used four times in this
subsystem, satisfies epic #8229's docstring criterion, and yields the device-side diagnostic for
free. B is deferred until a second caller exists. D is rejected on blast radius vs. evidence.

## Open Questions for /plan

- [ ] Exact dartdoc wording — must state the empty case, its destination, and cite #8261/#6294.
- [ ] Test placement inside the existing `group('classifyPotentialRequests', …)` without adding a
      shared-setup stub (baseline ceiling 14).
- [ ] Whether to assert the diagnostics log line, or only the routing.
- [ ] Whether the case-insensitive fix reuses `pubkeysEqual` — note `classifyPotentialRequests` is
      `static` and `_isSelf` is an instance method, so `pubkeysEqual` must be imported directly.

## Prerequisites

None. No design, protocol, or product decision is blocked — #8261 already ruled.

## Next Step

`/plan 7683`.
