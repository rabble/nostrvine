# Brainstorm: NIP-17 inbound duplicate handling (#6522)

Date: 2026-09-04

## Problem Statement

A NIP-17 receiver cannot tell a peer's **retry** — where the peer re-mints the
kind-14 rumor with a new event id and a new `created_at` but identical content —
apart from the user genuinely sending the same text twice. NIP-17 carries no
per-message correlation signal, so the receiver renders two bubbles for one
logical message. #6522 asks for "a protocol-level correlation signal, or another
sender/receiver contract that makes a retry distinguishable from a new send."

## What is already settled (see `tasks/findings_6522.md`)

Reproduced end-to-end on an iPhone 17 Simulator against the `local_stack`
funnelcake relay, with a hand-built NIP-59 peer: two gift wraps, identical
content, rumor `created_at` 30 s apart, distinct rumor ids. Both persisted into
one conversation; the thread rendered two identical bubbles.

- The duplicate is **deliberate, test-pinned behaviour**, not a latent defect.
  `direct_messages_dao_test.dart` (the re-minted-retry case) asserts
  `hasLength(2), reason: 'two rumor ids for one message render as two bubbles'`.
  It is the price of closing #7324, which was real, silent message *loss*.
- The **±5 s window is irrelevant here.** Post-#8169 the `DmDedupCounterpart`
  gate rejects a NIP-17-onto-NIP-17 match at *any* delta. Widening the window
  would not even reach this case — an independent reason the issue's first
  rejected approach is a dead end.
- **Divine never re-mints.** The retry path rebuilds from `row.rumorEventJson`
  via `Event.fromJson`, preserving the rumor id verbatim
  (`dm_repository.dart:4833-4841`, `:4934-4937`). Divine cannot cause this bug.
- **No NIP defines a correlator, and none has been proposed.** Verified against
  a `nostr-protocol/nips` clone at HEAD. kind 14 carries only `p`, `e`,
  `subject`, `q`.

## Constraints

- **Wire.** `59.md:126` requires independent random timestamps per layer to
  defeat metadata correlation, so any correlator must live **inside the
  encrypted rumor** — never on the seal or the gift wrap.
- **Pre-rejected by the issue:** widening the timestamp window, content-hash
  dedup, and receiver-side heuristic *suppression*.
- **Ruled by the maintainer for this work:** do not change Divine's outgoing
  wire format yet; lead with the sender/receiver contract rather than a new tag;
  leave the existing DAO test alone and add failing-first tests beside it; any
  correlator must be random per logical message and never reused.
- **Governance.** Epic #8227 belongs to the epic owner, and this repo routes
  protocol/product rulings to the epic owner even when implementation does not
  move with them (see the #8359 precedent). A wire-format change is such a
  ruling.
- Architecture: `UI -> BLoC/Cubit -> Repository -> Client`; the dedup decision
  belongs at the repository/DAO boundary, never in a widget.

## Prior Art

- `DirectMessagesDao.claimCrossProtocolTwin` — 1:1 claim semantics via
  `twin_collapsed`, a single `UPDATE ... WHERE id IN (SELECT ... LIMIT 1)`. The
  correct shape for "one message put on the wire twice yields exactly one
  counterpart."
- `DirectMessagesDao.hasMessageWithSendBatchId` — the group-send path already
  replaced a content window with an exact durable token. #7324's own
  "Suggested fix" named this as the correct end state, while noting it "only
  works for twins Divine itself minted." That caveat **is** #6522.
- #7633 (dedup logging), #8169 (counterpart gating), #8216, #8256.
- PR #8078 — draft, fixture-only request/spam prototype. Explicitly does not
  touch Nostr event formats. No overlap.

## Approaches Explored

### Approach A: Sender/receiver contract — "a retry MUST reuse the rumor"

**Description:** NIP-17 already states that a kind-14 rumor's `id` and
`created_at` are required fields, which makes the rumor id the message's
identity. Clarify in the spec that a client retrying delivery MUST re-wrap the
*same* rumor rather than mint a new one, because re-minting produces a different
message by definition. Divine already conforms.

**Layers affected:** none in the app. Documentation, plus an upstream spec diff.

**Pros:**
- Costs nothing on the wire and adds no new surface, no new tag, no privacy question.
- It is the *correct* end state: it removes the ambiguity rather than papering over it.
- Divine is already a conforming reference implementation, so we argue from practice.
- Frames re-minting as the peer's defect, which is what the spec's own model implies.

**Cons:**
- Fixes nothing until other clients adopt it. Adoption is outside our control.
- Upstream spec review is slow and may never merge.
- Offers no protection against a peer that ignores the clarification.

**Risks / Unknowns:** OQ8 — we do not know which clients re-mint today, so we
cannot predict how much a contract would change in practice.

**Complexity:** Low (for us).

### Approach B: Correlation tag inside the rumor

**Description:** Define a tag carried inside the kind-14 rumor holding a random,
per-logical-message identifier. A retry re-uses the value; two genuinely
different messages never share one. The receiver matches on it with claim-once
semantics, exactly as `claimCrossProtocolTwin` already does for the NIP-04 twin.

**Layers affected:** `nip17_message_service` (build/send) -> `dm_repository`
(ingest) -> `DirectMessagesDao` (new claim predicate + column).

**Pros:**
- Actually distinguishes retry from repeat — the only approach that does.
- Reuses a shape the codebase already has and trusts (claim-once, 1:1).
- Random-per-message means it correlates a retry to its original and nothing else.

**Cons:**
- New wire surface, and only helps against clients that adopt it — which is the
  same adoption problem as A, but with a permanent format commitment attached.
- The value is readable by every recipient of a group send and persists in their
  local database.
- Requires a DB migration and a change to the dedup contract the existing test pins.

**Risks / Unknowns:** tag-name bikeshedding upstream; whether a correlator should
survive an edit or a forward; interaction with the group-send byte-identical-rumor
invariant (#8188).

**Complexity:** Medium.

### Approach C: Disclosure instead of suppression

**Description:** Keep both rows, but surface the second as "possibly resent" with
a user-controlled collapse. Nothing is hidden and nothing is lost; the user
adjudicates rather than a heuristic.

**Layers affected:** DAO (derived flag) -> repository -> conversation UI.

**Pros:**
- Helps users today with no wire change and no peer cooperation.
- Fails safe in both directions: a false positive costs a collapsed bubble the
  user can expand, not a lost message.

**Cons:**
- Sits close to the issue's rejection of receiver-side handling. Even as
  disclosure rather than suppression, it is still a same-content heuristic.
- It is a product/UX decision, not an engineering one.

**Risks / Unknowns:** whether the epic owner reads "disclosure" as inside or
outside the rejection.

**Complexity:** Medium.

### Approach D: Harden the premise and make the failure observable

**Description:** Two gaps that exist regardless of which protocol direction wins.
First, Divine's never-re-mint property — the premise #6522 rests on — is
protected by a doc comment and nothing else; no test asserts that the retry path
preserves the rumor id. Second, a suspected peer re-mint is currently invisible:
it persists silently and looks identical to a genuine repeat in the logs. Add a
regression test locking the former, and a debug log line identifying the latter.

**Layers affected:** tests, plus one log statement on the ingest path.

**Pros:**
- Ships now, behind no ruling, with zero behavioural risk.
- Protects the exact invariant every other approach depends on. If someone later
  "optimises" the retry path into a fresh mint, Divine starts *causing* #6522.
- The log line is what makes OQ8 answerable from a support bug report.

**Cons:**
- Does not fix the duplicate. It hardens and measures.

**Risks / Unknowns:** none material. The log must carry full Nostr ids
(no truncation, `pubkeyForLogs` for pubkeys), and must never carry DM
plaintext, since these lines travel in Zendesk bug reports.

**Executed shape (revised during implementation).** The first attempt added a
dedicated `hasMatchingMessage` lookup on the ingest path and logged an explicit
"Possible peer re-mint" line. It worked and was mutation-validated, but it
broke 38 tests in `dm_repository_test.dart`: 25 pre-existing mock stubs there
match `hasMatchingMessage` without a `windowSeconds` matcher, so the new call
fell through to `null` and threw `type 'Null' is not a subtype of type
'Future<bool>'` inside the gift-wrap handler. Broadening 25 stub sites for a
debug log is the wrong trade, and guarding the call in a try/catch would have
made the suite green while the observation silently never ran — the precise
trap #8399 documents. The shipped version therefore adds no query at all: it
appends `contentLength` to the persist line that already exists, which carries
the rumor id, conversation id, sender and `created_at`. Same signature, zero
hot-path cost, no test churn.

**Complexity:** Low.

## Recommendation

**Ship D. Propose A. Specify B. Defer C.**

They compose rather than compete, and this split matches where the authority
actually sits: D is engineering hygiene that needs no ruling, A and B are
protocol decisions that belong to the epic owner.

D is recommended to ship because it is the only part that is unambiguously ours
to do, and because it protects the invariant on which A, B and the issue's own
premise all rest. A is recommended as the lead proposal because it removes the
ambiguity at its source at zero wire cost, and because Divine already conforms —
we would be asking the ecosystem to do what we already do, not to adopt something
we invented. B is specified but not implemented, because committing a tag name
and a DB migration before the ruling would be the expensive kind of guess.

C is deferred rather than dismissed: it is the only option that helps users
without peer cooperation, and it deserves an explicit product answer rather than
silent omission.

## Open Questions for /plan

- [ ] Where exactly does the re-mint observation hook go so it costs nothing on
      the happy path — before the insert, or as a branch of the existing
      counterpart lookup?
- [ ] Does the regression test for never-re-mint belong in
      `dm_repository_test.dart` or in a separate file? (#8169's lesson: a
      blanket-stubbed DAO in a shared setup can make such a test vacuous.)
- [ ] What is the exact NIP-17 diff wording for A?
- [ ] Does the new log line need a `pubkeyForLogs` call, and does it trip the
      nostr-id truncation or pubkey-encoding ratchets?

## Prerequisites

- [ ] Epic owner's ruling on A and B before any wire-format work begins.
- [ ] None for D.

## Next Step

`/plan 6522` for the D implementation, with the A proposal drafted in-repo for
the epic owner rather than filed upstream.
